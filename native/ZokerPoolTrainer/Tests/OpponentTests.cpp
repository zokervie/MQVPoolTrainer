// 0.40 Đấu với máy: the computer opponent must (1) always return a legal, finite stroke, (2) be deterministic for a
// seed, (3) pot more often as the level rises, (4) never choose a stroke its own simulation says loses the rack.
// Target pot-rate bands are ASSUMPTIONS (to tune against real players), checked loosely: monotone + end points.
#include "../BankLab/Core/Opponent.hpp"
#include <chrono>
#include <cstdio>
#include <iostream>
#include <stdexcept>
using namespace banklab;
namespace {
int assertions=0;
void check(bool c,const char* m){++assertions;if(!c)throw std::runtime_error(m);}
match::State playing(match::Discipline d){match::State s;s.rule=d;s.breakShot=false;s.ballInHand=false;s.headStringOnly=false;return s;}
/// One object ball (the lowest, legal) somewhere a club player would call "makeable", cue ball behind it.
std::vector<Ball> scenario(ai::Random& r,const Config& c){
    for(;;){
        Ball cue;cue.id=0;Ball one;one.id=1;
        one.p={(r.unit()-.5)*(c.width-.3),(r.unit()-.5)*(c.length-.4)};
        cue.p={(r.unit()-.5)*(c.width-.2),(r.unit()-.5)*(c.length-.3)};
        if((cue.p-one.p).length()<.25||(cue.p-one.p).length()>1.3)continue;
        World w(c);w.reset({cue,one});
        double best=0;for(int k=0;k<6;++k)best=std::max(best,ai::ease(w,cue.p,one,k));
        if(best>.08)return {cue,one};   // a real chance exists
    }
}
bool potted(const Outcome& o,int id){for(const auto& e:o.events)if(e.kind==2&&e.a==id&&e.b>=0)return true;return false;}
bool scratched(const Outcome& o){for(const auto& e:o.events)if(e.kind==2&&e.a==0)return true;return false;}
}
int main(){
    const auto started=std::chrono::steady_clock::now();
    const Config config;
    // 1. Determinism and validity on a fresh 9-ball rack (break) and after it.
    {
        match::Rules rules(match::Discipline::NineBall);World w(config);w.reset(rules.rack(7));
        for(int level=0;level<ai::kLevels;++level){
            const auto a=ai::execute(ai::plan(w,rules.state,level,42),level,42),b=ai::execute(ai::plan(w,rules.state,level,42),level,42);
            check(a.valid&&std::isfinite(a.angle)&&a.speed>0,"break stroke valid");
            check(a.angle==b.angle&&a.speed==b.speed&&a.side==b.side&&a.top==b.top,"same seed, same stroke");
            check(a.speed>=ai::skill(0).breakSpeed*.5,"break is struck firmly");
            check(std::hypot(a.side,a.top)<=0.711&&a.speed<=8&&a.elevation>=0&&a.elevation<=90,"the stroke passes the app's LANShot.isValid");
        }
        check(ai::skill(5).breakSpeed>ai::skill(0).breakSpeed,"stronger player breaks harder");
    }
    // 2. Pot rate rises with level on the same 1-ball positions; strokes are legal (first contact = ball 1).
    ai::Random r(2026);std::vector<std::vector<Ball>> layouts;for(int i=0;i<16;++i)layouts.push_back(scenario(r,config));
    std::array<int,ai::kLevels> pots{},legal{};
    for(int level=0;level<ai::kLevels;++level){
        for(size_t i=0;i<layouts.size();++i){
            World w(config);w.reset(layouts[i]);const auto s=playing(match::Discipline::NineBall);
            const auto planned=ai::plan(w,s,level,1000+i);
            check(planned.valid&&std::isfinite(planned.angle)&&planned.speed>0&&planned.speed<9,"a stroke is always returned");
            const auto shot=ai::execute(planned,level,7000+i*13+static_cast<size_t>(level));
            check(std::hypot(shot.side,shot.top)<=0.711&&shot.speed<=8&&shot.elevation>=0&&shot.elevation<=90,"executed stroke passes LANShot.isValid");
            const Outcome o=ai::play(w,shot,25);
            const auto j=ai::judge(w,s,o,0,1,-1);
            if(j.firstHit==1)++legal[static_cast<size_t>(level)];
            if(potted(o,1)&&!scratched(o))++pots[static_cast<size_t>(level)];
        }
        std::printf("REPORT level %-11s pots %2d/%zu legal %2d/%zu\n",ai::skill(level).name,pots[static_cast<size_t>(level)],layouts.size(),legal[static_cast<size_t>(level)],layouts.size());std::fflush(stdout);
    }
    const int n=static_cast<int>(layouts.size());
    check(pots[5]>=pots[0]+3,"AI pots clearly more than Beginner");
    check(pots[4]>=pots[1],"Pro pots at least as often as Amateur");
    for(size_t level=1;level<ai::kLevels;++level)check(pots[level]+1>=pots[level-1],"pot rate does not fall as the level rises (±1 of 16)");
    check(pots[4]>=pots[2]+3,"Pro clearly above Quarter Pro");
    check(pots[5]*10>=n*7,"AI pots >= 70% of makeable single-ball shots");
    check(pots[0]*10<=n*8,"Beginner misses a fair share");
    for(int level=0;level<ai::kLevels;++level)check(legal[static_cast<size_t>(level)]*10>=n*7,"first contact is the legal ball in most strokes");
    // 3. Never plan a stroke the simulation says loses (8-ball: early 8 on the table near a pocket in line).
    {
        Ball cue;cue.id=0;cue.p={0,-.6};Ball eight;eight.id=8;eight.p={0,.9};Ball two;two.id=2;two.p={.35,.2};
        World w(config);w.reset({cue,eight,two});auto s=playing(match::Discipline::EightBall);s.groups={{0,1}};
        for(int level=1;level<ai::kLevels;++level){
            const auto planned=ai::plan(w,s,level,5);check(planned.valid,"8-ball stroke valid");
            const auto j=ai::judge(w,s,ai::play(w,planned,25),0,planned.target,planned.pocket);
            check(!j.lost,"planned stroke never loses on the 8");
            check(planned.target!=8,"does not aim at the 8 with a group ball left");
        }
    }
    // 3b. Owner 12/11: "đến lượt máy cứ chờ" — a full table must plan inside the wall-clock budget at every level.
    for(auto rule:{match::Discipline::NineBall,match::Discipline::EightBall}){
        match::Rules rules(rule);World w(config);w.reset(rules.rack(11));
        const auto broke=w.simulate(ai::kPi/2,7.0,0,0,25);w.reset(broke.balls);
        bool cueOn=false;for(const auto& b:w.balls)if(b.id==0&&!b.sunk)cueOn=true;
        if(!cueOn){auto l=w.balls;for(auto& b:l)if(b.id==0){b.sunk=false;b.p={0,-.8};}w.reset(l);}
        auto s=playing(rule);if(rule==match::Discipline::EightBall)s.groups={{0,1}};
        for(int level=0;level<ai::kLevels;++level){
            const auto t0=std::chrono::steady_clock::now();
            const auto p=ai::plan(w,s,level,77,1.5);
            const double took=std::chrono::duration<double>(std::chrono::steady_clock::now()-t0).count();
            std::printf("REPORT full-table %s level %d planned in %.2f s\n",rule==match::Discipline::NineBall?"9-ball":"8-ball",level,took);std::fflush(stdout);
            check(p.valid,"full table: a stroke is always returned");
            const Ball* c=ai::find(w.balls,0);
            check(c&&ai::clearance(w,c->p,p.angle,p.side,p.top)<=p.elevation+0.01,"full table: the app accepts the stroke (cue lift clears rail and balls)");
            check(took<2.75,"full table: plan respects the 1.5 s budget (deadline checked between simulations)");
        }
    }
    // 5. 0.40c owner acceptance 12/11: "đánh quá đều đặn, không tư duy, không điều bi, không dùng lực/effect khác
    //    nhau, không biết nhảy/massé; có lúc dừng quá 10 s".
    {
        // a) Stall: the cue ball frozen behind another ball. Every level must return a stroke the app accepts
        //    (lift ≤ 30° clears rail and balls), never one the strike guard rejects in a loop.
        Ball cue;cue.id=0;cue.p={0.1,-0.2};Ball three;three.id=3;three.p={0.1,-0.2-2*config.radius-0.001};
        Ball one;one.id=1;one.p={0.1,0.5};Ball two;two.id=2;two.p={-0.4,0.9};
        World w(config);w.reset({cue,three,one,two});const auto s=playing(match::Discipline::NineBall);
        for(int level=0;level<ai::kLevels;++level){
            const auto p=ai::plan(w,s,level,9,1.5);
            check(p.valid,"frozen behind a ball: a stroke is returned");
            check(p.elevation<=ai::kMaxLift+1e-9||p.kind!=ai::Normal,"frozen: a normal stroke never needs more than 30 deg");
            check(ai::clearance(w,cue.p,p.angle,p.side,p.top)<=p.elevation+0.01,"frozen: the app's clearance guard accepts the stroke");
        }
    }
    {
        // b) Variety and position: on two-ball rotation layouts the strong player varies speed and spin to get on
        //    the next ball, and leaves better position than the Amateur.
        ai::Random g(77);std::vector<std::vector<Ball>> twos;
        while(twos.size()<14){
            auto l=scenario(g,config);Ball b2;b2.id=2;b2.p={(g.unit()-.5)*(config.width-.3),(g.unit()-.5)*(config.length-.4)};
            bool ok=true;for(const auto& b:l)if((b.p-b2.p).length()<.2)ok=false;
            if(ok){l.push_back(b2);twos.push_back(l);}
        }
        const auto s=playing(match::Discipline::NineBall);
        std::array<double,ai::kLevels> leaveSum{};std::array<int,ai::kLevels> potted{};
        std::vector<double> speeds,tops;bool english=false;
        for(int level:{1,4}){
            for(size_t i=0;i<twos.size();++i){
                World w(config);w.reset(twos[i]);
                const auto p=ai::plan(w,s,level,300+i,6.0);
                check(p.valid,"two-ball layout: a stroke is returned");
                if(level==4){speeds.push_back(std::round(p.speed*2)/2);tops.push_back(std::round(p.top*10)/10);if(p.side!=0)english=true;}
                const Outcome o=ai::play(w,p,25);const auto j=ai::judge(w,s,o,0,1,-1);
                if(j.potted){World after(config);after.reset(o.balls);auto n=s;leaveSum[static_cast<size_t>(level)]+=ai::offer(after,n,j.cue,0);++potted[static_cast<size_t>(level)];}
            }
        }
        std::sort(speeds.begin(),speeds.end());std::sort(tops.begin(),tops.end());
        const auto distinct=[](std::vector<double> v){return static_cast<int>(std::unique(v.begin(),v.end())-v.begin());};
        const double amateur=potted[1]?leaveSum[1]/potted[1]:0,pro=potted[4]?leaveSum[4]/potted[4]:0;
        std::printf("REPORT variety Pro: %d speeds, %d spins, english %d · leave Amateur %.3f (%d pots) Pro %.3f (%d pots)\n",distinct(speeds),distinct(tops),english?1:0,amateur,potted[1],pro,potted[4]);std::fflush(stdout);
        check(distinct(speeds)>=4,"Pro uses at least 4 different stroke speeds over 14 positions");
        check(distinct(tops)>=3,"Pro uses follow, centre and draw");
        check(pro>=amateur*1.15,"Pro leaves clearly better position than the Amateur");
    }
    {
        // c) Jump physics as the planner plays it: a jump-cue stroke over a blocker reaches the object ball first.
        Ball cue;cue.id=0;cue.p={0,-0.6};Ball five;five.id=5;five.p={0,-0.3};Ball one;one.id=1;one.p={0,0.25};
        World w(config);w.reset({cue,five,one});
        ai::Shot st;st.kind=ai::Jump;st.elevation=34;st.speed=4.8;st.angle=ai::kPi/2;
        check(ai::firstContact(w,st)==1,"a jump stroke clears the blocker and hits the object ball first");
        const auto s=playing(match::Discipline::NineBall);
        for(int level:{4,5}){
            const auto p=ai::plan(w,s,level,21,3.0);
            const auto j=ai::judge(w,s,ai::play(w,p,25),0,-1,-1);
            std::printf("REPORT blocked by the 5: level %d plays intent %d kind %d elev %.0f first hit %d\n",level,p.intent,p.kind,p.elevation,j.firstHit);std::fflush(stdout);
            check(j.firstHit==1,"Pro / AI escape the blocker legally (kick, jump or massé)");
        }
    }
    // 4. Referee choices.
    {match::State s;s.pendingChoice="push_out";s.choiceOptions={"accept","pass"};check(ai::chooseOption(s)=="accept","accepts a push-out table by default");}
    const double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    std::cout<<"Opponent tests passed: "<<assertions<<" assertions in "<<seconds<<" s\n";
    return 0;
}
