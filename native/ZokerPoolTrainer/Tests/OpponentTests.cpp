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
            const Outcome o=w.simulate(shot.angle,shot.speed,shot.side,shot.top,25);
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
            const auto j=ai::judge(w,s,w.simulate(planned.angle,planned.speed,planned.side,planned.top,25),0,planned.target,planned.pocket);
            check(!j.lost,"planned stroke never loses on the 8");
            check(planned.target!=8,"does not aim at the 8 with a group ball left");
        }
    }
    // 4. Referee choices.
    {match::State s;s.pendingChoice="push_out";s.choiceOptions={"accept","pass"};check(ai::chooseOption(s)=="accept","accepts a push-out table by default");}
    const double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    std::cout<<"Opponent tests passed: "<<assertions<<" assertions in "<<seconds<<" s\n";
    return 0;
}
