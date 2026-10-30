#pragma once
#include "Physics.hpp"
#include <array>
#include <cstdint>
#include <map>
#include <random>
#include <set>
#include <string>
#include <vector>

// Rules of virtual play, separate from the authoritative motion solver.
// WPA source: https://wpapool.com/wp-content/uploads/2026/01/2026.01.02-WPA-Rules.pdf
// Effective 2025-09-15, sections 3,4,5,6. Nine-ball break option: Regulation 16
// https://wpapool.com/wp-content/uploads/2025/10/2025.09.15-WPA-Regs-NP.pdf
// Rotation15 is an explicitly named 61-point practice variant, NOT a WPA discipline.
// Physical foot/touch/unsportsmanlike calls are outside virtual input evidence.
namespace banklab { namespace match {
enum class Discipline { EightBall, NineBall, TenBall, Rotation15 };
inline const char* name(Discipline d) {
    switch(d){case Discipline::EightBall:return "eightBall";case Discipline::TenBall:return "tenBall";
        case Discipline::Rotation15:return "rotation15";default:return "nineBall";}
}
inline Discipline discipline(const std::string& n) {
    if(n=="eightBall"||n=="8")return Discipline::EightBall;
    if(n=="tenBall"||n=="10")return Discipline::TenBall;
    if(n=="rotation15"||n=="15")return Discipline::Rotation15;
    return Discipline::NineBall;
}
struct Call {int ball=0,pocket=-1;bool safety=false,pushOut=false;};
struct Evidence {
    std::vector<Ball> before,after;
    std::vector<Event> events;
    // Unique object IDs observed beyond the head string at ANY time in the shot.
    // Final positions alone cannot establish a crossing followed by a return.
    std::set<int> headCrossed;
    Call call;
};
struct State {
    Discipline rule=Discipline::NineBall;
    int currentPlayer=0,winner=-1,shotCount=0;
    bool breakShot=true,ballInHand=true,headStringOnly=true,pushOutAvailable=false;
    std::array<int,2> groups{{-1,-1}},scores{{0,0}},fouls{{0,0}};
    std::array<bool,2> twoFoulWarning{{false,false}};
    std::string pendingChoice,reason="break";
    std::vector<std::string> choiceOptions;
    bool canShoot()const{return winner<0&&pendingChoice.empty();}
    bool requiresCall()const{return !breakShot&&(rule==Discipline::EightBall||rule==Discipline::TenBall);}
};
struct Action {State state;std::vector<int> spotBalls;bool accepted=false,rerack=false,foul=false;int shooter=0;std::string reason;};

class Rules {
public:
    explicit Rules(Discipline rule=Discipline::NineBall){state.rule=rule;}
    State state;
    bool threeBallBreak=true;
    void reset(int breaker=0){const auto rule=state.rule;state=State{};state.rule=rule;state.currentPlayer=breaker==1?1:0;previousShooter=state.currentPlayer;choiceScratch=false;}
    std::vector<Ball> rack(std::uint64_t seed)const {
        const double radius=.028575,diameter=2*radius+1e-6,rowHeight=std::sqrt(3.0)*diameter/2;
        const bool nine=state.rule==Discipline::NineBall;
        const int count=nine?9:(state.rule==Discipline::TenBall?10:15);
        std::vector<int> slots;
        for(int id=1;id<=count;++id)slots.push_back(id);
        std::mt19937_64 random(seed);
        for(std::size_t i=slots.size();i>1;--i)std::swap(slots[i-1],slots[random()%i]);
        auto force=[&](std::size_t at,int id){auto p=std::find(slots.begin(),slots.end(),id);std::iter_swap(slots.begin()+static_cast<std::ptrdiff_t>(at),p);};
        if(state.rule==Discipline::EightBall){force(4,8);
            const int solid=1+static_cast<int>(random()%7),stripe=9+static_cast<int>(random()%7);
            const bool solidLeft=(random()%2)==0;
            force(10,solidLeft?solid:stripe);force(14,solidLeft?stripe:solid);
        }else {force(0,1);if(nine)force(4,9);else if(count==10)force(4,10);else force(4,15);}
        Ball cue;cue.id=0;cue.p={0,-.90};std::vector<Ball> result{cue};
        const std::array<int,5> diamond{{1,2,3,2,1}};
        std::size_t index=0;const int rows=nine?5:(count==10?4:5);
        for(int row=0;row<rows;++row){const int width=nine?diamond[static_cast<std::size_t>(row)]:row+1;
            for(int col=0;col<width;++col){Ball b;b.id=slots[index++];
                b.p={(col-(width-1)/2.0)*diameter,.635+(row-(nine?2:0))*rowHeight};result.push_back(b);}}
        return result;
    }
    Action complete(const Evidence& e) {
        Action out;out.shooter=state.currentPlayer;
        if(!state.canShoot())return rejected("shot_not_allowed");
        if(!valid(e))return rejected("invalid_evidence");
        if(e.call.pushOut&&(!state.pushOutAvailable||state.breakShot))return rejected("push_out_unavailable");
        if(e.call.safety&&state.rule==Discipline::TenBall)return rejected("ten_ball_has_no_safety_call");
        const int shooter=state.currentPlayer,opponent=1-shooter;
        bool placementFoul=false;
        if(state.ballInHand){
            const auto cue=std::find_if(e.before.begin(),e.before.end(),[](const Ball& b){return b.id==0;});
            placementFoul=cue==e.before.end()||cue->sunk;
            if(cue!=e.before.end()){
                placementFoul=placementFoul||std::abs(cue->p.x)>.635-.028575+1e-8||std::abs(cue->p.y)>1.27-.028575+1e-8;
                if(state.headStringOnly&&cue->p.y>=-.635)placementFoul=true;
                for(const auto& b:e.before)if(b.id>0&&!b.sunk&&(b.p-cue->p).length()<.05715+1e-8)placementFoul=true;
            }
        }
        previousShooter=shooter;out.accepted=true;++state.shotCount;
        const bool breaking=state.breakShot,pushing=e.call.pushOut;
        state.ballInHand=false;state.headStringOnly=false;state.pushOutAvailable=false;
        std::set<int> potted,off,railed;
        std::map<int,int> pockets;
        int first=-1;bool railAfter=false,potAfter=false;
        for(const auto& event:e.events){
            if(event.kind==1&&first<0&&(event.a==0||event.b==0))first=event.a==0?event.b:event.a;
            else if(first>=0&&event.kind==0)railAfter=true;
            if(event.kind==0&&event.a>0)railed.insert(event.a);
            if(event.kind==2){if(event.b>=0){potted.insert(event.a);pockets[event.a]=event.b;if(first>=0&&event.a>0)potAfter=true;}
                else off.insert(event.a);}
        }
        const bool scratch=potted.count(0)||off.count(0);
        int objectPots=0;for(int id:potted)if(id>0)++objectPots;
        bool foul=scratch||!off.empty()||placementFoul;
        std::string reason=scratch?"scratch":(!off.empty()?"ball_off_table":(placementFoul?"bad_cue_ball_placement":""));
        const int lowest=lowestBall(e.before);
        const bool ready8=readyForEight(e.before,shooter);
        if(!pushing){
            bool wrong=first<0;
            if(state.rule==Discipline::EightBall){
                if(!breaking){const int group=state.groups[shooter];
                    const bool temporaryEight=ready8&&(e.call.ball==8||e.call.safety);
                    wrong=first<0||(group<0?(first==8&&!temporaryEight):(ready8?first!=8:ballGroup(first)!=group));}
            }else wrong=first!=lowest||first<0;
            if(wrong){foul=true;if(reason.empty())reason="wrong_ball_first";}
            if(!breaking&&!railAfter&&!potAfter){foul=true;if(reason.empty())reason="no_rail_after_contact";}
        }
        bool illegal8=false;
        if(breaking&&objectPots==0&&railed.size()<4){
            if(state.rule==Discipline::EightBall)illegal8=true;
            else {foul=true;if(reason.empty())reason="illegal_break_four_rails";}
        }
        out.foul=foul;
        if(state.rule==Discipline::EightBall&&breaking){
            state.fouls[shooter]=foul?state.fouls[shooter]+1:0;
            state.breakShot=false;
            if(potted.count(8)||off.count(8)){
                out.spotBalls.push_back(8);
                state.ballInHand=foul;state.headStringOnly=foul;
                choose("eight_break_eight",foul?opponent:shooter,{"spotAndPlay","rerackSelf"});
                state.reason=foul?"eight_on_foul_break":"eight_on_legal_break";choiceScratch=scratch;
            }else if(foul){state.ballInHand=true;state.headStringOnly=true;choiceScratch=scratch;
                choose("eight_break_foul",opponent,{"accept","ballInHand"});state.reason=reason;
            }else if(illegal8){choose("eight_illegal_break",opponent,{"accept","rerackSelf","rerackOpponent"});state.reason="illegal_break_four_rails";
            }else{state.fouls[shooter]=0;state.currentPlayer=objectPots>0?shooter:opponent;state.reason=objectPots>0?"legal_pot":"turn_passed";}
            return finish(out);
        }
        state.breakShot=false;
        if(state.rule==Discipline::EightBall&&(potted.count(8)||off.count(8))){
            const bool called=e.call.ball==8&&pockets.count(8)&&pockets[8]==e.call.pocket&&!e.call.safety;
            state.winner=(!foul&&!off.count(8)&&ready8&&called)?shooter:opponent;
            state.reason=state.winner==shooter?"eight_ball_win":(foul?"eight_on_foul":(!ready8?"early_eight":"eight_wrong_pocket"));
            return finish(out);
        }
        const int special=state.rule==Discipline::NineBall?9:state.rule==Discipline::TenBall?10:0;
        if(special&&(off.count(special)||potted.count(special))){
            const bool finalTen=state.rule==Discipline::TenBall&&!breaking&&countObjects(e.before)==1&&
                e.call.ball==10&&pockets.count(10)&&pockets[10]==e.call.pocket&&!pushing;
            if(foul||pushing||(breaking&&special==10)||(special==10&&!finalTen)||off.count(special))out.spotBalls.push_back(special);
        }
        if(foul){
            ++state.fouls[shooter];
            if(state.rule==Discipline::Rotation15){for(int id:potted)if(id>0)out.spotBalls.push_back(id);for(int id:off)if(id>0)out.spotBalls.push_back(id);}
            const bool threeFoulGame=state.rule==Discipline::NineBall||state.rule==Discipline::TenBall;
            if(threeFoulGame&&state.fouls[shooter]>=3&&state.twoFoulWarning[shooter]){
                state.winner=opponent;state.reason="three_consecutive_fouls";
            }else{
                if(threeFoulGame&&state.fouls[shooter]>=2)state.twoFoulWarning[shooter]=true;
                state.currentPlayer=opponent;state.ballInHand=true;state.reason=reason;
            }
            return finish(out);
        }
        state.fouls[shooter]=0;state.twoFoulWarning[shooter]=false;
        if(pushing){choose("push_out",opponent,{"accept","pass"});state.reason="push_out_choice";return finish(out);}
        if(breaking&&state.rule==Discipline::NineBall&&threeBallBreak){
            std::set<int> points=e.headCrossed;points.erase(0);for(int id:potted)if(id>0)points.insert(id);
            if(points.size()<3){
                if(potted.count(9)&&std::find(out.spotBalls.begin(),out.spotBalls.end(),9)==out.spotBalls.end())out.spotBalls.push_back(9);
                choose("nine_illegal_break",opponent,{"accept","pass"});state.reason="three_ball_break_not_met";return finish(out);
            }
        }
        if(state.rule==Discipline::NineBall&&potted.count(9)){state.winner=shooter;state.reason="nine_ball_win";return finish(out);}
        if(state.rule==Discipline::TenBall&&potted.count(10)&&!breaking&&countObjects(e.before)==1&&
            e.call.ball==10&&pockets[10]==e.call.pocket){state.winner=shooter;state.reason="ten_ball_win";return finish(out);}
        const bool calledMade=e.call.ball>0&&pockets.count(e.call.ball)&&pockets[e.call.ball]==e.call.pocket;
        if(state.rule==Discipline::EightBall){
            bool correctCall=calledMade&&!e.call.safety&&e.call.ball!=8;
            const int group=state.groups[shooter];
            if(group>=0&&ballGroup(e.call.ball)!=group)correctCall=false;
            if(correctCall&&group<0){state.groups[shooter]=ballGroup(e.call.ball);state.groups[opponent]=1-state.groups[shooter];}
            state.currentPlayer=correctCall?shooter:opponent;state.reason=correctCall?"called_pot":"turn_passed";
        }else if(state.rule==Discipline::TenBall){
            if(!breaking&&objectPots>0&&!calledMade){choose("ten_wrongful_pot",opponent,{"accept","pass"});state.reason="uncalled_ball_choice";}
            else{state.currentPlayer=(breaking?objectPots>0:calledMade)?shooter:opponent;state.reason=state.currentPlayer==shooter?"called_pot":"turn_passed";}
        }else if(state.rule==Discipline::Rotation15){
            for(int id:potted)if(id>0)state.scores[shooter]+=id;
            if(state.scores[shooter]>=61){state.winner=shooter;state.reason="rotation_61_win";}
            else{state.currentPlayer=objectPots>0?shooter:opponent;state.reason=objectPots>0?"points_scored":"turn_passed";}
        }else {state.currentPlayer=objectPots>0?shooter:opponent;state.reason=objectPots>0?"legal_pot":"turn_passed";}
        if(breaking&&(state.rule==Discipline::NineBall||state.rule==Discipline::TenBall))state.pushOutAvailable=true;
        return finish(out);
    }
    Action resolve(const std::string& option) {
        if(state.pendingChoice.empty()||std::find(state.choiceOptions.begin(),state.choiceOptions.end(),option)==state.choiceOptions.end())return rejected("invalid_choice");
        Action out;out.accepted=true;out.shooter=previousShooter;
        const std::string pending=state.pendingChoice;const int chooser=state.currentPlayer;
        if(option=="rerackSelf"||option=="rerackOpponent"){
            const int breaker=option=="rerackSelf"?chooser:1-chooser;reset(breaker);out.rerack=true;
        }else{
            if(option=="pass")state.currentPlayer=previousShooter;
            if(pending=="nine_illegal_break")state.pushOutAvailable=option=="pass";
            if(pending=="eight_break_foul"){
                state.ballInHand=option=="ballInHand"||choiceScratch;state.headStringOnly=state.ballInHand;
            }
            state.pendingChoice.clear();state.choiceOptions.clear();state.reason="choice_"+option;
        }
        return finish(out);
    }
private:
    int previousShooter=0;bool choiceScratch=false;
    static int ballGroup(int id){return id>=1&&id<=7?0:(id>=9&&id<=15?1:-1);}
    static int countObjects(const std::vector<Ball>& balls){int n=0;for(const auto& b:balls)if(b.id>0&&!b.sunk)++n;return n;}
    static int countGroup(const std::vector<Ball>& balls,int group){int n=0;for(const auto& b:balls)if(!b.sunk&&ballGroup(b.id)==group)++n;return n;}
    static int lowestBall(const std::vector<Ball>& balls){int n=99;for(const auto& b:balls)if(b.id>0&&!b.sunk)n=std::min(n,b.id);return n==99?-1:n;}
    bool readyForEight(const std::vector<Ball>& balls,int shooter)const{
        const int group=state.groups[shooter];return group>=0?countGroup(balls,group)==0:countGroup(balls,0)==0||countGroup(balls,1)==0;
    }
    static bool valid(const Evidence& e){
        if(e.before.empty()||e.after.empty())return false;
        std::set<int> ids;
        for(const auto& b:e.before){if(b.id<0||b.id>15||!std::isfinite(b.p.x)||!std::isfinite(b.p.y)||!ids.insert(b.id).second)return false;}
        if(!ids.count(0))return false;
        std::set<int> afterIDs;
        for(const auto& b:e.after){if(!ids.count(b.id)||!std::isfinite(b.p.x)||!std::isfinite(b.p.y)||!afterIDs.insert(b.id).second)return false;}
        if(ids!=afterIDs)return false;
        if(e.call.ball<0||e.call.ball>15||e.call.pocket< -1||e.call.pocket>5)return false;
        for(int id:e.headCrossed)if(id<=0||!ids.count(id))return false;
        double last=-1;
        for(const auto& event:e.events){if(event.kind<0||event.kind>2||event.a<0||event.a>15||!std::isfinite(event.time)||event.time<last||event.time<0)return false;
            if(!ids.count(event.a))return false;
            if(event.kind==1&&!ids.count(event.b))return false;
            if(event.kind==0&&(event.b<0||event.b>3))return false;
            if(event.kind==2&&(event.b< -1||event.b>5))return false;
            last=event.time;}
        return true;
    }
    void choose(const std::string& kind,int player,std::vector<std::string> options){state.pendingChoice=kind;state.currentPlayer=player;state.choiceOptions=std::move(options);}
    Action rejected(const std::string& reason)const{Action a;a.state=state;a.reason=reason;return a;}
    Action finish(Action a)const{a.state=state;a.reason=state.reason;std::sort(a.spotBalls.begin(),a.spotBalls.end());a.spotBalls.erase(std::unique(a.spotBalls.begin(),a.spotBalls.end()),a.spotBalls.end());return a;}
};
}}
