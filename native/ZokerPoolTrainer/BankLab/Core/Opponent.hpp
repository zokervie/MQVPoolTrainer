#pragma once
// Computer opponent ("Đấu với máy"), six levels. 0.40: owner request 11/11/2026. 0.40c: owner acceptance 12/11/2026
// ("máy đánh quá đều đặn, không tư duy, không biết điều bi, không dùng lực/effect khác nhau, không biết nhảy/massé;
// có lúc dừng quá 10 s").
//
// Method (computational-pool practice: PickPocket, U. Alberta; CueCard, Computer Olympiad 2008 — generate shots by
// type, play each forward in the real simulator, estimate success under the player's own execution noise, value the
// position that is left, play safe when the pot is poor):
//   1. Shot generation by type: direct pot, one-rail bank (Quarter Pro+), combination (Semi Pro+), jump / massé pot
//      and escape (Pro / AI), kick escape (Quarter Pro+), safety.
//   2. A stroke menu per level: speed classes (soft … power), follow/stun/draw and side english. Every candidate is
//      played forward on a copy of the real World with the SAME physics settings the app will use for that stroke
//      (cue type, elevation over a rail, tip, squirt) — see strokeConfig.
//   3. Position: the leave is valued as the next shot's ease (and the one after for Pro / AI: pattern play).
//   4. Monte Carlo (Quarter Pro+): the best few candidates are replayed with the level's own hand error, so a player
//      picks the stroke that works for HIS hand (CueCard), not the one that works only when executed perfectly.
//   5. Anytime search under a wall-clock Deadline checked between simulations: there is always a legal stroke.
// Skill numbers are ASSUMPTIONS to be tuned against real ratings, not measurements:
//   aim error (1 sigma)  0.65°, 0.47°, 0.33°, 0.24°, 0.17°, 0.08°  for Beginner … AI; tip error 0.10 … 0.02 R.
// Deterministic: the same world, state, level and seed always give the same stroke.
#include "MatchRules.hpp"
#include "../UI/CueClearance.h"
#include "../UI/ShotKindPolicy.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

namespace banklab { namespace ai {

constexpr double kPi=3.14159265358979323846;
constexpr int kLevels=6;

/// Stroke kinds, numbered like the app's shot kinds (ShotKindPolicy.h): 0 normal, 1 jump cue, 2 break cue, 3 massé.
enum Kind {Normal=0,Jump=1,BreakCue=2,Masse=3};
/// What the stroke is meant to do (for tempo, the status line and tests).
enum Plan {Pot=0,Bank=1,Combo=2,JumpPot=3,MassePot=4,Safety=5,Kick=6,JumpEscape=7,MasseEscape=8,Roll=9,Break=10};

struct Skill {
    const char* name;
    double aimSigma;      // rad, 1 sigma
    double speedSigma;    // fraction of the planned speed
    double tipSigma;      // side/top offset in ball radii
    bool centreWindow;    // aims at the middle of the measured pot window instead of the geometric ghost ball
    int lookahead;        // 0 = pot only, 1 = values the next shot, 2 = also the shot after (pattern)
    double safetyBelow;   // plays safe when the best pot chance is below this (0 = never)
    bool escapes;         // searches kicks when snookered
    double blunder;       // chance to take another option on purpose (mistake of choice, not of hand)
    double breakSpeed;    // m/s
    int options;          // (ball, pocket) pairs examined
    int speeds;           // speed classes used (kSpeeds, from the middle out)
    int spins;            // 1 centre, 2 + follow, 3 + draw, 5 draw/stun/centre/follow/strong follow
    bool english;         // side spin for position
    bool banks,combos,jump,masse;
    int samples;          // Monte Carlo replays of the best candidates (0 = trust the window)
    double posWeight;     // weight of the leave against the pot itself
};
/// Simulated seconds per candidate: a pool shot is decided (pot/foul/position) inside 8 s.
constexpr double kJudgeSeconds=8;   // CI 131: 12 s made one full-table simulation the size of the overrun
/// Highest cue lift (deg) for a normal stroke over a rail / ball; above it the stroke must be a jump or a massé.
constexpr double kMaxLift=30;
struct Deadline {
    std::chrono::steady_clock::time_point start,end;
    explicit Deadline(double seconds):start(std::chrono::steady_clock::now()),end(start+std::chrono::duration_cast<std::chrono::steady_clock::duration>(std::chrono::duration<double>(seconds>1e6?1e6:seconds))){}
    bool over()const{return std::chrono::steady_clock::now()>end;}
    /// True once `fraction` of the budget is spent (phases share one turn).
    bool past(double fraction)const{return std::chrono::steady_clock::now()>start+std::chrono::duration_cast<std::chrono::steady_clock::duration>((end-start)*fraction);}
};
inline const Skill& skill(int level){
    static const std::array<Skill,kLevels> table={{
        //  name          aim°          speed tip  window look safe  esc  blunder brk  opt spd spin eng  bank combo jump masse  mc  pos
        {"Beginner",   0.65*kPi/180,.20,.10,false,0,0.00,false,.25,4.0, 3,  2,  1,  false,false,false,false,false,0, 0.0},
        {"Amateur",    0.47*kPi/180,.14,.08,true, 0,0.00,false,.12,5.0, 4,  2,  2,  false,false,false,false,false,0, 0.0},
        {"Quarter Pro",0.33*kPi/180,.10,.06,true, 1,0.20,true, .06,6.0, 5,  3,  3,  false,true, false,false,false,3, 1.0},
        {"Semi Pro",   0.24*kPi/180,.07,.04,true, 2,0.30,true, .03,6.8, 6,  4,  5,  true, true, true, false,false,4, 1.4},
        {"Pro",        0.17*kPi/180,.05,.03,true, 2,0.40,true, .00,7.4, 7,  5,  5,  true, true, true, true, false,5, 1.7},
        {"AI",         0.08*kPi/180,.02,.02,true, 2,0.45,true, .00,7.8, 8,  5,  5,  true, true, true, true, true, 6, 2.0}}};
    return table[static_cast<size_t>(std::clamp(level,0,kLevels-1))];
}
/// Object-ball run past the pocket (m) for each speed class, middle-out so a level with few classes uses the common ones.
constexpr std::array<double,5> kSpeeds{{1.1,0.6,1.8,0.3,2.9}};
/// Vertical tip offsets (R): centre, follow, draw, stun, strong follow.
constexpr std::array<double,5> kSpins{{0.0,0.42,-0.45,-0.18,0.55}};

/// A planned or executed stroke. `angle` is the direction the cue ball is struck (physics); the app's aim angle is
/// `aimAngle()` (0.43: identical — the cue strokes parallel to the aim line).
struct Shot {
    double angle=0,speed=0,side=0,top=0,elevation=0;
    int kind=Normal,intent=Roll;
    int target=-1,pocket=-1;
    bool safety=false,placed=false,valid=false;
    V2 place{};
    double potChance=0,value=-std::numeric_limits<double>::infinity();
    double think=1.0;     // seconds a player of this level would spend on this decision (tempo, not computation)
};

/// splitmix64: tiny, seedable, identical on every platform (std::normal_distribution is not).
struct Random {
    std::uint64_t state;
    explicit Random(std::uint64_t seed):state(seed? seed:0x9E3779B97F4A7C15ULL){}
    std::uint64_t next(){std::uint64_t z=(state+=0x9E3779B97F4A7C15ULL);z=(z^(z>>30))*0xBF58476D1CE4E5B9ULL;z=(z^(z>>27))*0x94D049BB133111EBULL;return z^(z>>31);}
    double unit(){return (next()>>11)*(1.0/9007199254740992.0);}
    double normal(){double u=std::max(unit(),1e-12),v=unit();return std::sqrt(-2*std::log(u))*std::cos(2*kPi*v);}
};

/// Physics settings the app applies for a stroke (UI/MatchPlayController strike + shotKindPhysics); the planner must
/// simulate exactly what will be played, otherwise a raised cue's squirt or a jump cue's tip makes the plan miss.
inline Config strokeConfig(Config c,int kind,double elevation){
    const int shotKind=kind==Normal&&elevation>35?Masse:kind;   // as the match strike: `cueType == 0 && elevation > 35 ? 3`
    c.cueType=kind==Jump?1:kind==BreakCue?2:0;
    c.cueElevationDegrees=elevation;
    c.experimental3D=elevation>35||kind==Jump;
    c.squirtEnabled=true;   // 0.43: squirtRampDegrees stays the app's (15 = level cue straight, 0 = "Squirt thực tế")
    c.masseCoupledContact=BLMasseCoupledForShotKind(shotKind)>0;
    c.tipProfile=BLTipForShotKind(shotKind);
    return c;
}
/// Play a stroke forward on a copy of `w` with the stroke's own physics settings.
inline Outcome play(const World& w,const Shot& s,double seconds=kJudgeSeconds){
    World t(strokeConfig(w.config,s.kind,s.elevation));t.reset(w.balls);
    return t.simulate(s.angle,s.speed,s.side,s.top,seconds);
}
/// Aim angle the app must be given for a stroke along `s.angle`. 0.43: the cue strokes PARALLEL to the aim line (the
/// old bridge-hand pivot of TableScene.cuePose turned side english into a 0.8–1.0° stroke-line error TOWARD the english
/// side, the opposite of real squirt) — the aim is the stroke line; squirt comes only from the physics (TP A.31).
inline double aimAngle(const Shot& s,double){return s.angle;}

inline std::array<V2,6> pockets(const Config& c){
    const double x=c.width/2,y=c.length/2;   // same catch basins as World::pocket
    return {V2{-x-.035,-y-.035},V2{x+.035,-y-.035},V2{-x-.071,0},V2{x+.071,0},V2{-x-.035,y+.035},V2{x+.035,y+.035}};
}
/// Where to send an object ball: a point just inside each pocket mouth (centre of the opening on the playing surface).
inline std::array<V2,6> mouths(const Config& c){
    const double x=c.width/2,y=c.length/2,r=c.radius;
    return {V2{-x+r*.6,-y+r*.6},V2{x-r*.6,-y+r*.6},V2{-x-r*.2,0},V2{x+r*.2,0},V2{-x+r*.6,y-r*.6},V2{x-r*.6,y-r*.6}};
}
inline const Ball* find(const std::vector<Ball>& balls,int id){for(const auto& b:balls)if(b.id==id&&!b.sunk)return &b;return nullptr;}
// Same definitions as match::Rules (private there); kept identical so the opponent never disagrees with the referee.
inline int ballGroup(int id){return id>=1&&id<=7?0:(id>=9&&id<=15?1:-1);}
inline int countGroup(const std::vector<Ball>& balls,int group){int n=0;for(const auto& b:balls)if(!b.sunk&&ballGroup(b.id)==group)++n;return n;}
inline int lowestBall(const std::vector<Ball>& balls){int n=99;for(const auto& b:balls)if(b.id>0&&!b.sunk)n=std::min(n,b.id);return n==99?-1:n;}

/// May `id` be the first object ball struck by `player`?
inline bool legalFirst(const match::State& s,const std::vector<Ball>& balls,int id,int player){
    if(id<=0)return false;
    using D=match::Discipline;
    if(s.rule!=D::EightBall)return id==lowestBall(balls);
    const int group=s.groups[static_cast<size_t>(player)];
    if(s.breakShot)return true;
    if(group<0)return id!=8;
    if(countGroup(balls,group)==0)return id==8;
    return ballGroup(id)==group;
}
/// Is potting `id` good for `player` (keeps the turn or wins)? The 8 before its time is handled by the caller.
inline bool wantedPot(const match::State& s,const std::vector<Ball>& balls,int id,int player){
    using D=match::Discipline;
    if(id<=0)return false;
    if(s.rule==D::EightBall){
        const int group=s.groups[static_cast<size_t>(player)];
        if(id==8)return group>=0&&countGroup(balls,group)==0;
        return group<0||ballGroup(id)==group;
    }
    return true;
}
inline int moneyBall(const match::State& s){
    using D=match::Discipline;
    return s.rule==D::EightBall?8:s.rule==D::NineBall?9:s.rule==D::TenBall?10:-1;
}

/// Is the straight segment a→b free of other balls (within one ball diameter of the path)?
inline bool clearPath(const std::vector<Ball>& balls,V2 a,V2 b,int ignoreA,int ignoreB,double radius){
    const V2 d=b-a;const double len=d.length();if(len<1e-9)return true;
    const V2 u=d*(1/len);
    for(const auto& o:balls){
        if(o.sunk||o.id==ignoreA||o.id==ignoreB)continue;
        const V2 rel=o.p-a;const double along=rel.x*u.x+rel.y*u.y;
        if(along<=0||along>=len)continue;
        const double across=std::abs(rel.x*u.y-rel.y*u.x);
        if(across<2*radius*1.02)return false;
    }
    return true;
}
/// Lift (deg) the cue needs to clear the rail and the balls behind the cue ball (UI/CueClearance.h — the same test
/// the app applies before it accepts a stroke).
inline double clearance(const World& w,V2 cue,double angle,double side,double top){
    std::vector<double> xs,ys;
    for(const auto& b:w.balls)if(!b.sunk&&b.id!=0){xs.push_back(b.p.x);ys.push_back(b.p.y);}
    return BLCueMinimumElevationBalls(cue.x,cue.y,angle,side,top,w.config.width,w.config.length,w.config.radius,w.config.railHeight,
                                      xs.data(),ys.data(),static_cast<int>(xs.size()));
}
/// Lift for a normal stroke: the clearance plus half a degree, 0 on an open table; negative when a normal stroke
/// cannot be played there (needs more than kMaxLift).
inline double liftFor(const World& w,V2 cue,double angle,double side,double top){
    const double need=clearance(w,cue,angle,side,top);
    if(need<=0.01)return 0;
    return need+0.5<=kMaxLift?need+0.5:-1;
}

/// Geometric ease of potting `object` into pocket `k` from `cue`: 0 (impossible) … ~1 (short, straight).
/// `blockedCueOk`: ignore balls on the cue-ball path (jump / massé candidates).
inline double ease(const World& w,V2 cue,const Ball& object,int k,bool blockedCueOk=false){
    const auto m=mouths(w.config);const double r=w.config.radius;
    const V2 toPocket=m[static_cast<size_t>(k)]-object.p;const double dp=toPocket.length();if(dp<1e-6)return 0;
    const V2 u=toPocket*(1/dp);const V2 ghost=object.p-u*(2*r);
    const V2 toGhost=ghost-cue;const double dc=toGhost.length();if(dc<1e-6)return 0;
    const double cut=(toGhost.x*u.x+toGhost.y*u.y)/dc;          // cos(cut angle)
    if(cut<0.26)return 0;                                       // thinner than ~75°
    if(std::abs(ghost.x)>w.config.width/2-r*.5||std::abs(ghost.y)>w.config.length/2-r*.5)return 0;
    if(!clearPath(w.balls,object.p,m[static_cast<size_t>(k)],0,object.id,r))return 0;
    if(!blockedCueOk&&!clearPath(w.balls,cue,ghost,0,object.id,r))return 0;
    // Side pockets reject balls arriving along the rail.
    if(k==2||k==3){const double open=std::abs(u.x);if(open<0.45)return 0;}
    return cut*cut/(1+0.9*dc+1.3*dp);
}
/// Best ease over every legal ball and pocket from a cue position (what the table "offers" a player).
inline double offer(const World& w,const match::State& s,V2 cue,int player){
    double best=0;
    for(const auto& b:w.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,w.balls,b.id,player)||!wantedPot(s,w.balls,b.id,player))continue;
        for(int k=0;k<6;++k)best=std::max(best,ease(w,cue,b,k));
    }
    return best;
}
/// Value of the position left for `player`'s next shot. depth 2 adds the shot after (pattern play): in rotation the
/// ball after the next one, seen from the next ball; in 8-ball the second-best option (more choices = safer run).
/// Small penalties: cue ball near a pocket (scratch risk) or frozen on a cushion (bridge over the rail).
inline double leave(const World& after,const match::State& s,V2 cue,int player,int depth){
    using D=match::Discipline;
    std::vector<std::pair<double,int>> eases;
    for(const auto& b:after.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,after.balls,b.id,player)||!wantedPot(s,after.balls,b.id,player))continue;
        double e=0;for(int k=0;k<6;++k)e=std::max(e,ease(after,cue,b,k));
        eases.push_back({e,b.id});
    }
    if(eases.empty())return 0;
    std::sort(eases.begin(),eases.end(),[](const auto& a,const auto& b){return a.first>b.first;});
    double v=eases.front().first;
    if(depth>=2){
        if(s.rule!=D::EightBall){
            const Ball* next=find(after.balls,eases.front().second);
            int second=99;for(const auto& b:after.balls)if(!b.sunk&&b.id>0&&next&&b.id!=next->id)second=std::min(second,b.id);
            if(next&&second<99)if(const Ball* nb=find(after.balls,second)){double e=0;for(int k=0;k<6;++k)e=std::max(e,ease(after,next->p,*nb,k));v+=0.35*e;}
        }else{if(eases.size()>1)v+=0.33*eases[1].first;if(eases.size()>2)v+=0.15*eases[2].first;}   // 0.42: PickPocket top-3 weights 1/.33/.15
    }
    const double r=after.config.radius;
    for(const V2 p:mouths(after.config))if((p-cue).length()<0.10)v-=0.05;
    if(std::abs(cue.x)>after.config.width/2-r*1.15||std::abs(cue.y)>after.config.length/2-r*1.15)v-=0.03;
    return v;
}

struct Judgement {bool foul=false,potted=false,won=false,lost=false,keepsTurn=false;V2 cue{};int firstHit=-1;};
/// Referee's view of one simulated stroke (subset of MatchRules needed to rank strokes; the real Rules still decide).
inline Judgement judge(const World& before,const match::State& s,const Outcome& o,int player,int target,int pocket){
    Judgement j;double contactTime=-1;bool railAfter=false,anyPot=false,cueSunk=false,targetInPocket=false;
    std::vector<int> potted;
    for(const auto& e:o.events){
        if(e.kind==1&&j.firstHit<0&&(e.a==0||e.b==0)){j.firstHit=e.a==0?e.b:e.a;contactTime=e.time;}
        else if(e.kind==0&&contactTime>=0&&e.time>=contactTime)railAfter=true;
        else if(e.kind==2){
            if(e.a==0)cueSunk=true;
            else{anyPot=true;potted.push_back(e.a);if(e.a==target&&(pocket<0||e.b==pocket))targetInPocket=true;if(e.b<0)j.foul=true;}
        }
    }
    if(const Ball* c=find(o.balls,0))j.cue=c->p;
    if(cueSunk||j.firstHit<0||!legalFirst(s,before.balls,j.firstHit,player)||(!anyPot&&!railAfter))j.foul=true;
    const int money=moneyBall(s);
    using D=match::Discipline;
    for(int id:potted){
        if(id==money){
            if(s.rule==D::EightBall){
                const bool ready=wantedPot(s,before.balls,8,player);
                if(ready&&!j.foul&&targetInPocket&&target==8)j.won=true;else j.lost=true;
            }else if(s.rule==D::NineBall){if(!j.foul)j.won=true;}
            else if(s.rule==D::TenBall){if(!j.foul&&target==10&&targetInPocket)j.won=true;}
        }
    }
    if(!j.foul){
        if(s.rule==D::NineBall||s.rule==D::Rotation15)j.keepsTurn=anyPot;
        else if(s.rule==D::TenBall)j.keepsTurn=targetInPocket;
        else for(int id:potted)if(id!=8&&wantedPot(s,before.balls,id,player))j.keepsTurn=true;
    }
    j.potted=targetInPocket&&!j.foul;
    return j;
}

/// Stroke speed that carries the object ball to the pocket and `extra` metres beyond (rolling resistance only;
/// ASSUMED margin, the simulation is the judge).
inline double paceFor(const World& w,double cueTravel,double objectTravel,double cutCos,double extra){
    const double g=9.81,mu=w.config.rolling;
    const double vObject=std::sqrt(2*mu*g*(objectTravel+extra));
    const double vCueAtImpact=vObject/std::max(0.2,cutCos);
    // A struck ball slides first and keeps ~5/7 of its speed once rolling (Shepard; Alciatore TP 4.1), and a cut
    // transfers speed only along the line of centres; 1.45 covers both plus throw losses (CALIBRATED in
    // OpponentTests: the planned pace must drop the ball at the geometric line, not die in the jaws).
    const double v=1.45*std::sqrt(vCueAtImpact*vCueAtImpact+2*mu*g*cueTravel)+0.15;
    return std::clamp(v,0.8,7.5);
}

/// One potting idea before any simulation: what to hit, where it should go, and the geometric aim.
struct Idea {int ball=-1,pocket=-1,plan=Pot;double aim=0,cueTravel=0,objectTravel=0,cutCos=1,e=0;bool blocked=false;};
struct Candidate {Shot shot;double chance=0,width=0,leave=0,value=0;Judgement outcome{};};

/// Find the pot window around `stroke.angle`: centre and angular width (rad) of the aim range that pots.
/// 0.40c: nearest-first probes (0, ±0.25°, ±0.5°, … ±2.1°) — a typical window is only ~0.5° wide, so the old uniform
/// 0.6–0.7° grid could step over it — then each edge is walked out in 0.15° steps and bisected 3 times (≈0.02°).
inline bool potWindow(const World& w,const match::State& s,int player,int target,int k,Shot stroke,double& centre,double& width,const Deadline* deadline=nullptr,double span=2.1*kPi/180){
    const double geometric=stroke.angle,deg=kPi/180;
    auto pots=[&](double a){stroke.angle=a;const Judgement j=judge(w,s,play(w,stroke),player,target,k);return j.potted&&!j.lost;};
    double found=0;bool any=false;const double scale=std::max(1.0,span/(2.1*deg));   // wider span: same probes, spread out
    for(double o:{0.0,0.25,-0.25,0.5,-0.5,0.8,-0.8,1.15,-1.15,1.6,-1.6,2.1,-2.1}){
        if(deadline&&deadline->over())break;   // CI 131: one slow candidate must not blow the turn budget
        if(std::abs(o*deg)>span+1e-12)continue;
        if(pots(geometric+o*scale*deg)){found=geometric+o*scale*deg;any=true;break;}
    }
    if(!any)return false;
    auto edge=[&](double dir){
        double in=found,out=found+dir*0.15*deg;
        for(int i=0;i<6&&pots(out);++i){in=out;out+=dir*0.15*deg;if(deadline&&deadline->over())return in;}
        const int refine=deadline&&deadline->over()?0:3;
        for(int i=0;i<refine;++i){const double m=(in+out)/2;if(pots(m))in=m;else out=m;}
        return in;
    };
    const double hi=edge(1),lo=edge(-1);
    centre=(lo+hi)/2;width=std::max(hi-lo,0.02*deg);
    return true;
}
/// Chance that a normally distributed aim error stays inside a window of the given width.
inline double chanceInside(double width,double sigma){return sigma<=0?1:std::erf(width/(2*std::sqrt(2.0)*sigma));}

/// Cue-ball position for ball in hand: behind the easiest legal ball at a natural angle for position (a slight cut,
/// not dead straight); behind the head string when required.
inline V2 placeCue(const World& w,const match::State& s,int player){
    const double r=w.config.radius,hx=w.config.width/2-r*1.2,hy=w.config.length/2-r*1.2;
    auto free=[&](V2 p){
        if(std::abs(p.x)>hx||std::abs(p.y)>hy)return false;
        if(s.headStringOnly&&p.y>=-w.config.length/4-r)return false;
        for(const auto& b:w.balls)if(!b.sunk&&b.id>0&&(b.p-p).length()<2*r*1.05)return false;
        return true;
    };
    if(s.breakShot){
        for(double x:{-0.22,0.22,-0.12,0.12,0.0}){V2 p{x,-w.config.length/4-0.16};if(free(p))return p;}
    }
    V2 best{0,-w.config.length/4-0.2};double bestEase=-1;
    const auto m=mouths(w.config);
    for(const auto& b:w.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,w.balls,b.id,player)||!wantedPot(s,w.balls,b.id,player))continue;
        for(int k=0;k<6;++k){
            const V2 d=m[static_cast<size_t>(k)]-b.p;const double len=d.length();if(len<1e-6)continue;
            const V2 u=d*(1/len),side{-u.y,u.x};
            for(double back:{0.30,0.42,0.22,0.55})for(double cut:{0.0,0.12,-0.12}){
                const V2 p=b.p-u*(2*r+back)+side*(back*cut);
                if(!free(p))continue;
                const double e=ease(w,p,b,k)*(cut!=0?1.02:1.0);   // slight angle: easier to send the cue ball on
                if(e>bestEase){bestEase=e;best=p;}
            }
        }
    }
    if(bestEase>0)return best;
    for(double y:{-0.9,-0.72,-1.1,0.0,0.45,-0.45,0.9})for(double x:{0.0,-0.14,0.14,-0.28,0.28,-0.42,0.42}){V2 p{x,y};if(free(p))return p;}
    return best;
}

/// Potting ideas from the geometry: direct, one-rail bank, combination, and pots behind a blocker (jump / massé).
inline std::vector<Idea> ideas(const World& w,const match::State& s,int player,const Skill& k){
    std::vector<Idea> out;const Ball* cue=find(w.balls,0);if(!cue)return out;
    const double r=w.config.radius,hx=w.config.width/2-r,hy=w.config.length/2-r;const auto m=mouths(w.config);
    auto aimAt=[&](V2 ghost,V2 u,Idea& i){const V2 line=ghost-cue->p;i.cueTravel=line.length();i.aim=std::atan2(line.y,line.x);i.cutCos=i.cueTravel>1e-9?(line.x*u.x+line.y*u.y)/i.cueTravel:0;};
    for(const auto& b:w.balls){
        if(b.sunk||b.id<=0)continue;
        const bool first=legalFirst(s,w.balls,b.id,player),wanted=wantedPot(s,w.balls,b.id,player);
        for(int pk=0;pk<6;++pk){
            const V2 toPocket=m[static_cast<size_t>(pk)]-b.p;const double dp=toPocket.length();if(dp<1e-6)continue;
            const V2 u=toPocket*(1/dp);
            if(first&&wanted){
                const double e=ease(w,cue->p,b,pk);
                if(e>0){Idea i;i.ball=b.id;i.pocket=pk;i.plan=Pot;i.objectTravel=dp;i.e=e;aimAt(b.p-u*(2*r),u,i);out.push_back(i);}
                else if(k.jump){
                    const double eb=ease(w,cue->p,b,pk,true);
                    if(eb>0){Idea i;i.ball=b.id;i.pocket=pk;i.plan=JumpPot;i.objectTravel=dp;i.e=eb*0.45;i.blocked=true;aimAt(b.p-u*(2*r),u,i);out.push_back(i);}
                }
            }
        }
        // One-rail bank: mirror the pocket across each cushion line the object ball can reach (corner pockets only
        // for the long rails; banks into a side pocket off the short rail are out of a club player's repertoire).
        if(k.banks&&first&&wanted){
            for(int pk=0;pk<6;++pk){
                const V2 mp=m[static_cast<size_t>(pk)];
                const std::array<V2,4> images{{V2{2*hx-mp.x,mp.y},V2{-2*hx-mp.x,mp.y},V2{mp.x,2*hy-mp.y},V2{mp.x,-2*hy-mp.y}}};
                for(int rail=0;rail<4;++rail){
                    const V2 img=images[static_cast<size_t>(rail)];const V2 d=img-b.p;const double dl=d.length();if(dl<1e-6)continue;
                    const V2 u=d*(1/dl);
                    // Bounce point must be on that rail, not past a pocket.
                    const double t=rail<2?((rail==0?hx:-hx)-b.p.x)/(u.x==0?1e-9:u.x):((rail==2?hy:-hy)-b.p.y)/(u.y==0?1e-9:u.y);
                    if(t<=0.05||t>=dl)continue;
                    const V2 hit=b.p+u*t;
                    if(rail<2?(std::abs(hit.y)>hy-0.12||std::abs(hit.y)<0.12):(std::abs(hit.x)>hx-0.12))continue;
                    const V2 ghost=b.p-u*(2*r);const V2 line=ghost-cue->p;const double dc=line.length();if(dc<1e-6)continue;
                    const double cut=(line.x*u.x+line.y*u.y)/dc;if(cut<0.5)continue;
                    if(!clearPath(w.balls,cue->p,ghost,0,b.id,r)||!clearPath(w.balls,b.p,hit,0,b.id,r)||!clearPath(w.balls,hit,mp,0,b.id,r))continue;
                    Idea i;i.ball=b.id;i.pocket=pk;i.plan=Bank;i.objectTravel=dl;i.e=0.45*cut*cut/(1+0.9*dc+1.6*dl);aimAt(ghost,u,i);out.push_back(i);
                }
            }
        }
    }
    // Combination: the legal ball A sends ball B into a pocket (9-ball: B = 9 wins).
    if(k.combos){
        for(const auto& a:w.balls){
            if(a.sunk||a.id<=0||!legalFirst(s,w.balls,a.id,player))continue;
            for(const auto& b:w.balls){
                if(b.sunk||b.id<=0||b.id==a.id||!wantedPot(s,w.balls,b.id,player))continue;
                if(s.rule==match::Discipline::EightBall&&b.id==8)continue;   // 8 on a combo needs a call the opponent rarely gives
                const double ab=(b.p-a.p).length();if(ab>0.6)continue;          // long combos are not a percentage shot
                for(int pk=0;pk<6;++pk){
                    const double eb=ease(w,a.p,b,pk,true);if(eb<=0)continue;
                    const V2 toPocket=m[static_cast<size_t>(pk)]-b.p;const V2 ub=toPocket*(1/toPocket.length());
                    const V2 ghostB=b.p-ub*(2*r);const V2 dA=ghostB-a.p;const double la=dA.length();if(la<1e-6)continue;
                    const V2 ua=dA*(1/la);const V2 ghostA=a.p-ua*(2*r);
                    const double cutB=(dA.x*ub.x+dA.y*ub.y)/la;if(cutB<0.8)continue;
                    const V2 line=ghostA-cue->p;const double dc=line.length();if(dc<1e-6)continue;
                    const double cutA=(line.x*ua.x+line.y*ua.y)/dc;if(cutA<0.6)continue;
                    if(!clearPath(w.balls,cue->p,ghostA,0,a.id,r)||!clearPath(w.balls,a.p,ghostB,a.id,b.id,r))continue;
                    const bool money=b.id==moneyBall(s);
                    Idea i;i.ball=b.id;i.pocket=pk;i.plan=Combo;i.objectTravel=la+toPocket.length();i.e=(money?0.9:0.35)*eb*cutA*cutA;
                    aimAt(ghostA,ua,i);i.cutCos=cutA*cutB;out.push_back(i);
                }
            }
        }
    }
    std::sort(out.begin(),out.end(),[](const Idea& x,const Idea& y){return x.e>y.e;});
    return out;
}

/// First object ball the cue ball touches (−1: none / scratch), stepping only until that contact — a cheap test for
/// kick lines before the full simulation.
inline int firstContact(const World& w,const Shot& st,double horizon=6){
    World t(strokeConfig(w.config,st.kind,st.elevation));t.reset(w.balls);t.strike(st.angle,st.speed,st.side,st.top);
    const int limit=static_cast<int>(horizon/World::stepSize);
    for(int i=0;i<limit&&t.moving();++i){
        const size_t seen=t.events.size();t.step();
        for(size_t e=seen;e<t.events.size();++e){
            const Event& ev=t.events[e];
            if(ev.kind==1&&(ev.a==0||ev.b==0))return ev.a==0?ev.b:ev.a;
            if(ev.kind==2&&ev.a==0)return -1;
        }
    }
    return -1;
}

/// Plan a stroke (no hand error). `world` must be at rest with the cue ball already placed.
inline Shot plan(const World& world,const match::State& s,int level,std::uint64_t seed,double budgetSeconds=1e9){
    Shot out;const Deadline deadline(budgetSeconds);const Skill& k=skill(level);Random rng(seed^(0xA5A5ULL*static_cast<std::uint64_t>(level+1)));
    const int player=s.currentPlayer;
    const Ball* cue=find(world.balls,0);if(!cue)return out;
    const double r=world.config.radius;
    match::State next=s;next.breakShot=false;

    if(s.breakShot){
        // Full hit on the apex; better players break harder, a touch of follow, from the side rail.
        int apex=-1;double nearest=1e9;
        for(const auto& b:world.balls){if(b.sunk||b.id<=0)continue;const double d=(b.p-cue->p).length();if(d<nearest){nearest=d;apex=b.id;}}
        if(apex<0)return out;
        const Ball* a=find(world.balls,apex);
        out.angle=std::atan2(a->p.y-cue->p.y,a->p.x-cue->p.x);out.speed=k.breakSpeed;out.top=level>=3?0.15:0;
        out.elevation=std::max(0.0,liftFor(world,cue->p,out.angle,0,out.top));
        out.target=apex;out.valid=true;out.value=0;out.intent=Break;out.think=1.2+0.4*level/5.0;
        // 0.42 (research: an optimised break is worth ~10 % of games — CueCard): Semi Pro and up try a small menu of
        // breaks with their own hand error and keep the one that most often keeps the turn without scratching and
        // parks the cue ball near the centre (pros: "cue ball in the middle"). Anytime: the plain break stands.
        if(level>=3){
            Random br(seed^0xB4EAull);double bestScore=-1e9;Shot best=out;
            const double baseAngle=out.angle;
            for(double off:{0.0,0.35,-0.35,0.7,-0.7})for(double top:{-0.12,0.05,0.18})for(double pace:{1.0,0.92}){
                if(deadline.past(0.85))break;
                Shot st=out;st.angle=baseAngle+off*kPi/180;st.top=top;st.speed=k.breakSpeed*pace;
                const double lift=liftFor(world,cue->p,st.angle,0,top);if(lift<0)continue;st.elevation=std::max(0.0,lift);
                double sc=0;int n=0;
                for(int t=0;t<3&&!deadline.past(0.9);++t){
                    Shot h=st;h.angle+=k.aimSigma*br.normal();h.speed=std::clamp(h.speed*(1+k.speedSigma*br.normal()),0.4,8.0);h.top+=k.tipSigma*br.normal();
                    const Outcome o=play(world,h,6);const Judgement j=judge(world,s,o,player,-1,-1);++n;
                    if(j.lost)sc-=4;else if(j.foul)sc-=2;else if(j.keepsTurn)sc+=1.0-0.35*j.cue.length();else sc-=0.1*j.cue.length();
                }
                if(n==0){continue;}
                sc/=n;
                if(sc>bestScore){bestScore=sc;best=st;}
            }
            out=best;
        }
        return out;
    }

    // Evaluate one concrete stroke: simulate it, judge it, value the leave.
    auto evaluate=[&](Candidate& c,int target,int pocket){
        const Outcome o=play(world,c.shot);
        c.outcome=judge(world,s,o,player,target,pocket);
        c.leave=0;
        if(k.lookahead>0||k.posWeight>0)if(c.outcome.potted&&!c.outcome.won){
            World after(world.config);after.reset(o.balls);
            c.leave=leave(after,next,c.outcome.cue,player,k.lookahead);
            if(k.lookahead>1&&c.leave<=0)c.leave=-0.15;   // no shot afterwards hurts a strong player more
        }
        return o;
    };
    auto score=[&](Candidate& c){
        const double win=c.outcome.won?4.0:0;
        const double miss=k.lookahead>0?0.35:0.1;
        c.value=c.chance*(1.0+win+k.posWeight*c.leave)-(1-c.chance)*miss;
    };

    // 1. Ideas → pot windows (phase budget 35 %).
    std::vector<Idea> list=ideas(world,s,player,k);
    if(list.size()>static_cast<size_t>(k.options))list.resize(static_cast<size_t>(k.options));
    double bestDirect=0;for(const Idea& d:list)if(d.plan==Pot)bestDirect=std::max(bestDirect,d.e);
    std::vector<Candidate> pots;
    for(const Idea& idea:list){
        if(deadline.past(0.35)&&!pots.empty())break;
        if(deadline.over())break;
        if(idea.plan==Bank&&bestDirect>0.12)continue;   // a bank is the answer only when nothing straight is on
        Candidate c;c.shot.target=idea.ball;c.shot.pocket=idea.pocket;c.shot.intent=idea.plan;
        const size_t pick=k.centreWindow?0:static_cast<size_t>(rng.next()%static_cast<std::uint64_t>(k.speeds));
        c.shot.speed=paceFor(world,idea.cueTravel,idea.objectTravel,idea.cutCos,kSpeeds[pick]);
        c.shot.angle=idea.aim;
        if(idea.plan==JumpPot){
            if(clearance(world,cue->p,idea.aim,0,0)>32)continue;
            c.shot.kind=Jump;c.shot.elevation=32;c.shot.speed=std::clamp(c.shot.speed*1.25,3.6,6.5);
            double centre=idea.aim,width=0;
            if(!potWindow(world,s,player,idea.ball,idea.pocket,c.shot,centre,width,&deadline,1.6*kPi/180))continue;
            c.shot.angle=centre;c.width=width;c.chance=chanceInside(width,k.aimSigma*1.6);   // a jump stroke is less accurate
        }else{
            const double lift=liftFor(world,cue->p,idea.aim,0,0);
            if(lift<0)continue;   // the cue cannot reach this line with a normal stroke (the 0.40b stall)
            c.shot.elevation=lift;
            if(k.centreWindow){
                double centre=idea.aim,width=0;bool ok=false;
                const double span=(idea.plan==Bank?4.0:2.1)*kPi/180;
                // Base stroke: a firm pot (1.1 m past the pocket); if the ball dies short, firmer (1.8 m).
                for(size_t vi:{size_t(0),size_t(2)}){
                    if(deadline.over())break;
                    c.shot.speed=paceFor(world,idea.cueTravel,idea.objectTravel,idea.cutCos,kSpeeds[vi]);c.shot.angle=idea.aim;
                    if(potWindow(world,s,player,idea.ball,idea.pocket,c.shot,centre,width,&deadline,span)){ok=true;break;}
                }
                if(!ok)continue;
                c.shot.angle=centre;c.width=width;c.chance=chanceInside(width,k.aimSigma);
            }else c.chance=std::clamp(idea.e*1.6,0.05,0.9);   // Beginner: trusts the ghost ball, finds out on the table
        }
        evaluate(c,idea.ball,idea.pocket);
        if(c.outcome.lost)continue;
        if(k.centreWindow&&!c.outcome.potted)continue;
        score(c);pots.push_back(c);
    }
    std::sort(pots.begin(),pots.end(),[](const Candidate& a,const Candidate& b){return a.value>b.value;});

    // 2. Stroke menu on the best ideas: speed × follow/stun/draw (× side for Pro / AI). The window centre is kept;
    //    a variant that no longer pots there is retried a third of a window either side (throw changes with spin).
    if(k.speeds>1||k.spins>1){
        const size_t ideasToVary=std::min<size_t>(pots.size(),level>=3?3:2);
        std::vector<Candidate> variants;
        for(size_t i=0;i<ideasToVary;++i){
            const Candidate base=pots[i];
            if(base.shot.kind!=Normal)continue;
            const Idea* idea=nullptr;for(const auto& d:list)if(d.ball==base.shot.target&&d.pocket==base.shot.pocket&&d.plan==base.shot.intent){idea=&d;break;}
            if(!idea)continue;
            std::vector<std::pair<double,double>> english{{0.0,1.0}};
            if(k.english){english.push_back({0.3,0.75});english.push_back({-0.3,0.75});}
            for(const auto& [side,topScale]:english)
            for(int si=0;si<k.spins;++si)for(int vi=0;vi<k.speeds;++vi){
                if(deadline.past(0.7))break;
                const double top=kSpins[static_cast<size_t>(si)]*topScale;
                if(si==0&&vi==0&&side==0)continue;   // that is the base stroke
                Candidate c=base;c.shot.side=side;c.shot.top=top;
                c.shot.speed=paceFor(world,idea->cueTravel,idea->objectTravel,idea->cutCos,kSpeeds[static_cast<size_t>(vi)]);
                // Draw needs a firmer stroke to survive the slide to the object ball (TP 4.x): add with distance.
                if(top<0)c.shot.speed=std::min(7.5,c.shot.speed+0.35*idea->cueTravel);
                const double lift=liftFor(world,cue->p,c.shot.angle,side,top);if(lift<0)continue;c.shot.elevation=lift;
                bool ok=false;
                for(double off:{0.0,1.0/3,-1.0/3}){
                    if(deadline.over())break;
                    c.shot.angle=base.shot.angle+off*base.width;
                    evaluate(c,base.shot.target,base.shot.pocket);
                    if(c.outcome.potted&&!c.outcome.lost){ok=true;c.chance=chanceInside(base.width*(off==0?1.0:0.8),k.aimSigma)*(side!=0?0.95:1.0);break;}
                }
                if(!ok)continue;
                score(c);variants.push_back(c);
            }
        }
        pots.insert(pots.end(),variants.begin(),variants.end());
        std::sort(pots.begin(),pots.end(),[](const Candidate& a,const Candidate& b){return a.value>b.value;});
    }

    // 3. Monte Carlo with the level's own hand (CueCard: fewer than 30 replays per deciding candidate loses; 30–50 is
    //    enough). 0.42: successive halving — every candidate gets a first round, the better half more, the top few up to
    //    50 — all under the anytime deadline. The analytic window chance is a prior worth 4 replays (Bayes), so a
    //    candidate the clock cut short is not swung by luck. Quarter Pro: 6/15; Semi Pro and up: 10/30/50.
    if(k.samples>0&&!pots.empty()){
        Random mc(seed*0x2545F4914F6CDD1DULL+static_cast<std::uint64_t>(level));
        struct Tally{int n=0,potted=0,fouls=0,lost=0;double leaveSum=0,prior=0,priorLeave=0;};
        std::vector<Tally> tally(pots.size());
        for(size_t i=0;i<pots.size();++i){tally[i].prior=pots[i].chance;tally[i].priorLeave=pots[i].leave;}
        const std::vector<int> rounds=k.samples>=4?std::vector<int>{10,30,50}:std::vector<int>{6,15};
        const std::vector<size_t> keep=k.samples>=4?std::vector<size_t>{8,4,2}:std::vector<size_t>{5,2};
        auto rescore=[&](size_t i){
            Candidate& c=pots[i];const Tally& t=tally[i];if(t.n==0)return;
            const double w=4.0,p=static_cast<double>(t.potted)/t.n,f=static_cast<double>(t.fouls)/t.n,l=static_cast<double>(t.lost)/t.n;
            c.chance=(w*t.prior+t.n*p)/(w+t.n);
            const double avgLeave=t.potted>0?t.leaveSum/t.potted:t.priorLeave;
            c.leave=(w*t.priorLeave+t.potted*avgLeave)/(w+t.potted);
            score(c);c.value-=0.8*f+6.0*l;
        };
        std::vector<size_t> alive;for(size_t i=0;i<std::min(pots.size(),keep[0]);++i)alive.push_back(i);
        for(size_t round=0;round<rounds.size()&&!alive.empty();++round){
            if(deadline.past(0.88))break;
            for(size_t i:alive){
                Candidate& c=pots[i];Tally& t=tally[i];
                while(t.n<rounds[round]){
                    if(deadline.past(0.88))break;
                    Shot h=c.shot;h.angle+=k.aimSigma*mc.normal()*(c.shot.kind==Jump?1.6:1.0);h.speed=std::clamp(h.speed*(1+k.speedSigma*mc.normal()),0.4,8.0);
                    h.side=std::clamp(h.side+k.tipSigma*mc.normal(),-0.6,0.6);h.top=std::clamp(h.top+k.tipSigma*mc.normal(),-0.7,0.7);
                    const Outcome o=play(world,h);const Judgement j=judge(world,s,o,player,c.shot.target,c.shot.pocket);++t.n;
                    if(j.lost)++t.lost;else if(j.foul)++t.fouls;
                    if(j.potted&&!j.lost){++t.potted;if(!j.won){World after(world.config);after.reset(o.balls);t.leaveSum+=leave(after,next,j.cue,player,k.lookahead);}}
                }
                rescore(i);
            }
            std::sort(alive.begin(),alive.end(),[&](size_t x,size_t y){return pots[x].value>pots[y].value;});
            if(round+1<keep.size()&&alive.size()>keep[round+1])alive.resize(keep[round+1]);
        }
        std::sort(pots.begin(),pots.end(),[](const Candidate& a,const Candidate& b){return a.value>b.value;});
    }

    auto fill=[&](const Candidate& c,bool safety){
        out=c.shot;out.pocket=safety?-1:c.shot.pocket;out.safety=safety;out.potChance=c.chance;out.value=c.value;out.valid=true;
        if(safety&&out.intent<Safety)out.intent=Safety;
        // The final line may differ from the one the lift was measured on (window centre, variant): re-measure, so the
        // app's clearance guard never rejects the stroke (0.40b: rejected strokes looped and the computer "waited").
        if(out.kind==Normal&&out.elevation<BL_MASSE_ELEVATION){
            const double l=liftFor(world,cue->p,out.angle,out.side,out.top);
            if(l>out.elevation)out.elevation=l;
            else if(l<0)out.elevation=std::min(BL_MASSE_ELEVATION-1,clearance(world,cue->p,out.angle,out.side,out.top)+0.5);
        }
    };
    const Candidate* bestPot=pots.empty()?nullptr:&pots.front();
    if(bestPot&&k.blunder>0&&pots.size()>1&&rng.unit()<k.blunder){
        // Human-like mistake of choice: take another option, not the best one.
        bestPot=&pots[static_cast<size_t>(rng.next()%pots.size())];
    }
    const bool wantSafety=k.safetyBelow>0&&(!bestPot||bestPot->chance<k.safetyBelow);
    auto finish=[&](){
        // Tempo (not computation): easy shots go quickly, hard choices and special strokes take longer.
        const double hard=1-std::clamp(out.potChance,0.0,1.0);
        out.think=0.7+1.4*hard+(out.safety?0.9:0)+(out.kind!=Normal?0.8:0)+0.6*rng.unit()-(level==0?0.3:0);
        out.think=std::clamp(out.think,0.6,3.5);
    };
    if(bestPot&&!wantSafety){fill(*bestPot,false);finish();return out;}

    // 4. Safety / escape. Is the cue ball snookered (no straight line to any legal ball)?
    bool snookered=true;
    for(const auto& b:world.balls)if(!b.sunk&&b.id>0&&legalFirst(s,world.balls,b.id,player)&&clearPath(world.balls,cue->p,b.p,0,b.id,r*0.98)){snookered=false;break;}
    if(k.safetyBelow>0||k.escapes||!bestPot){
        Candidate best;bool found=false;double bestScore=-1e9;
        auto consider=[&](Shot st){
            if(deadline.over())return;
            // A raised cue must still clear the rail and the balls behind the cue ball (a ball frozen behind it blocks
            // even a jump cue).
            if((st.kind!=Normal||st.elevation>kMaxLift)&&clearance(world,cue->p,st.angle,st.side,st.top)>st.elevation)return;
            const Outcome o=play(world,st);
            const Judgement j=judge(world,s,o,player,-1,-1);
            if(j.lost)return;
            double sc;
            if(j.foul)sc=-2.0;
            else{
                World after(world.config);after.reset(o.balls);
                sc=j.keepsTurn?0.6+offer(after,next,j.cue,player):-offer(after,next,j.cue,1-player);
                if(st.kind!=Normal)sc-=0.05;   // a plain stroke is preferred when it is as good
            }
            if(sc>bestScore){bestScore=sc;found=true;best.shot=st;best.shot.target=j.firstHit;best.shot.pocket=-1;best.chance=0;best.value=sc;}
        };
        // a) Rolls and cuts to each legal ball at several speeds (and draw/stop for strong players).
        const std::vector<double> speeds=level>=3?std::vector<double>{1.1,1.9,2.8}:std::vector<double>{1.6,2.6};
        const std::vector<double> tops=level>=3?std::vector<double>{0.0,-0.35}:std::vector<double>{0.0};
        for(const auto& b:world.balls){
            if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
            const double base=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);
            for(double off:{0.0,0.012,-0.012,0.024,-0.024})for(double v:speeds)for(double t:tops){
                if(deadline.over())break;
                Shot st;st.angle=base+off;st.speed=v;st.top=t;st.intent=Safety;
                const double lift=liftFor(world,cue->p,st.angle,0,t);if(lift<0)continue;st.elevation=lift;consider(st);
            }
        }
        // b) Kicks: one- and two-rail mirror lines to the nearest legal balls, fanned ±3° (rebound is not a mirror).
        if(k.escapes&&(snookered||!found||bestScore<-0.5)){
            const double hx=world.config.width/2-r,hy=world.config.length/2-r;
            std::vector<const Ball*> targets;
            for(const auto& b:world.balls)if(!b.sunk&&b.id>0&&legalFirst(s,world.balls,b.id,player))targets.push_back(&b);
            std::sort(targets.begin(),targets.end(),[&](const Ball* a,const Ball* b){return (a->p-cue->p).length()<(b->p-cue->p).length();});
            if(targets.size()>2)targets.resize(2);
            for(const Ball* t:targets){
                std::vector<V2> images;
                for(V2 p:{V2{2*hx-t->p.x,t->p.y},V2{-2*hx-t->p.x,t->p.y},V2{t->p.x,2*hy-t->p.y},V2{t->p.x,-2*hy-t->p.y}})images.push_back(p);
                if(level>=3)for(double sx:{1.0,-1.0})for(double sy:{1.0,-1.0})images.push_back(V2{2*sx*hx-t->p.x,2*sy*hy-t->p.y});
                for(V2 img:images)for(double v:{2.4,1.8,3.2}){
                    bool hit=false;
                    for(int f=0;f<=16&&!hit;++f){
                        if(deadline.over())break;
                        const double off=(f%2?1:-1)*((f+1)/2)*0.5*kPi/180;   // 0, ±0.5°, … ±4° (rebound is not a mirror)
                        Shot st;st.angle=std::atan2(img.y-cue->p.y,img.x-cue->p.x)+off;st.speed=v;st.intent=Kick;
                        const double lift=liftFor(world,cue->p,st.angle,0,0);if(lift<0)continue;st.elevation=lift;
                        if(firstContact(world,st)!=t->id)continue;
                        consider(st);hit=true;   // first line that reaches the ball on this image; the fan is its tolerance
                    }
                    if(hit)break;
                }
            }
        }
        // c) Pro / AI: jump over the blocker; AI: massé around it.
        if(k.jump&&(snookered||bestScore<-0.5)){
            for(const auto& b:world.balls){
                if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
                if((b.p-cue->p).length()<0.25)continue;   // too close to get the cue ball airborne first
                const double base=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);
                for(double el:{30.0,38.0})for(double v:{3.8,4.8,5.8})for(double off:{0.0,0.015,-0.015}){
                    if(deadline.over())break;
                    Shot st;st.kind=Jump;st.elevation=el;st.angle=base+off;st.speed=v;st.intent=JumpEscape;consider(st);
                }
            }
        }
        if(k.masse&&(snookered||bestScore<-0.5)){
            for(const auto& b:world.balls){
                if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
                const double base=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);
                for(double side:{0.45,-0.45})for(double off:{0.12,0.22,0.32})for(double v:{1.4,2.2}){
                    if(deadline.over())break;
                    // Swing out to the side opposite the english and let the curve bring the ball back.
                    Shot st;st.kind=Normal;st.elevation=70;st.side=side;st.top=-0.1;st.speed=v;st.intent=MasseEscape;
                    st.angle=base+(side>0?off:-off);consider(st);
                    st.angle=base-(side>0?off:-off);consider(st);
                }
            }
        }
        // A weak pot is still better than a poor safety.
        if(found&&(!bestPot||bestScore>bestPot->value-0.25)){fill(best,true);finish();return out;}
    }
    if(bestPot){fill(*bestPot,false);finish();return out;}

    // Nothing better: roll at the nearest legal ball (a beginner's answer to a snooker), with a liftable line.
    double nearest=1e9;
    for(const auto& b:world.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
        const double d=(b.p-cue->p).length();const double a=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);
        const double lift=liftFor(world,cue->p,a,0,0);
        if(d<nearest&&lift>=0){nearest=d;out.angle=a;out.target=b.id;out.elevation=lift;}
    }
    if(nearest>=1e9){
        // Every line to a legal ball needs too much lift: any direction the cue can reach (always exists away from
        // the blocking rail) — never leave the turn hanging.
        double want=kPi/2,closest=1e9;
        for(const auto& b:world.balls)if(!b.sunk&&b.id>0&&legalFirst(s,world.balls,b.id,player)){const double d=(b.p-cue->p).length();if(d<closest){closest=d;want=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);}}
        double bestDiff=1e9;
        for(int i=0;i<144;++i){
            const double a=want+(i%2?1:-1)*((i+1)/2)*2.5*kPi/180;const double lift=liftFor(world,cue->p,a,0,0);
            if(lift>=0&&std::abs(a-want)<bestDiff){bestDiff=std::abs(a-want);nearest=0;out.angle=a;out.elevation=lift;break;}
        }
    }
    if(nearest<1e9){out.speed=2.0;out.safety=true;out.valid=true;out.value=-1;out.intent=Roll;}
    finish();
    return out;
}

/// The stroke as the hand delivers it: planned stroke plus the level's execution error.
inline Shot execute(const Shot& planned,int level,std::uint64_t seed){
    Shot s=planned;if(!s.valid)return s;
    const Skill& k=skill(level);Random rng(seed^0x51ED270B0B5ULL);
    s.angle+=k.aimSigma*rng.normal()*(s.kind==Jump||s.elevation>=BL_MASSE_ELEVATION?1.6:1.0);
    s.speed=std::clamp(s.speed*(1+k.speedSigma*rng.normal()),0.4,8.0);
    s.side=std::clamp(s.side+k.tipSigma*rng.normal(),-0.6,0.6);
    s.top=std::clamp(s.top+k.tipSigma*rng.normal(),-0.7,0.7);
    // The app rejects a tip point outside 0.711 R (LANShot.isValid) — keep the hand inside the miscue limit.
    if(const double h=std::hypot(s.side,s.top);h>0.65){s.side*=0.65/h;s.top*=0.65/h;}
    if(s.elevation>0)s.elevation=std::clamp(s.elevation+(s.kind==Jump||s.elevation>=BL_MASSE_ELEVATION?1.5:0.2)*rng.normal(),planned.elevation-0.2,85.0);
    return s;
}

/// Answer to a referee choice (push-out, illegal break …): simple, level-independent policy.
inline std::string chooseOption(const match::State& s){
    auto has=[&](const char* o){return std::find(s.choiceOptions.begin(),s.choiceOptions.end(),o)!=s.choiceOptions.end();};
    if(s.pendingChoice=="eight_break_foul"&&has("ballInHand"))return "ballInHand";
    if(s.pendingChoice=="eight_break_eight"&&has("spotAndPlay"))return "spotAndPlay";
    if(has("accept"))return "accept";
    return s.choiceOptions.empty()?std::string():s.choiceOptions.front();
}

}} // namespace banklab::ai
