#pragma once
// 0.40 — Computer opponent ("Đấu với máy"), six levels. Owner request 11/11/2026.
//
// The opponent does not use a separate, simplified table model: every candidate stroke is played forward on a copy of
// the real World (World::simulate) and judged from the events the referee would see. A level is two things:
//   - hand: execution error added to the planned stroke (aim / speed / tip offset), drawn from a seeded generator;
//   - head: how the stroke is chosen (does it centre the pot window, look one ball ahead, play safe, escape a snooker).
// Skill numbers are ASSUMPTIONS to be tuned against real ratings, not measurements:
//   aim error (1 sigma)  0.65°, 0.47°, 0.33°, 0.24°, 0.17°, 0.08°  for Beginner … AI.
//   Chosen so that on this engine's MEDIAN pot window (~0.5° wide at 1–1.5 m, measured by potWindow) the expected
//   Tip error (side/top, ball radii) 0.10 … 0.02: unintended side squirts the cue ball ~1° per 0.1 R on this engine,
//   so it is part of the aim budget, not on top of it.
//   pot rate on a makeable ball is ~30 / 40 / 55 / 70 / 85 / 95 % (assumed targets, to tune with real players).
// Deterministic: the same world, state, level and seed always give the same stroke.
#include "MatchRules.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

namespace banklab { namespace ai {

constexpr double kPi=3.14159265358979323846;
constexpr int kLevels=6;

struct Skill {
    const char* name;
    double aimSigma;      // rad, 1 sigma
    double speedSigma;    // fraction of the planned speed
    double tipSigma;      // side/top offset in ball radii
    bool centreWindow;    // aim at the middle of the pot window instead of the geometric ghost ball
    int lookahead;        // 0 = pot only, 1 = leave a shot on the next ball, 2 = also value the ball after
    bool usesSpin;        // tries follow/draw for position
    double safetyBelow;   // play safe when the best pot chance is below this (0 = never)
    bool escapes;         // searches kicks when no direct legal contact exists
    double blunder;       // chance to take a worse option on purpose (human-like mistake in choice, not in hand)
    double breakSpeed;    // m/s
};
inline const Skill& skill(int level){
    static const std::array<Skill,kLevels> table={{
        {"Beginner",   0.65*kPi/180,.20,.10,false,0,false,0.00,false,.25,4.0},
        {"Amateur",    0.47*kPi/180,.14,.08,true, 0,false,0.00,false,.12,5.0},
        {"Quarter Pro",0.33*kPi/180,.10,.06,true, 1,false,0.20,true, .06,6.0},
        {"Semi Pro",   0.24*kPi/180,.07,.04,true, 1,true, 0.30,true, .03,6.8},
        {"Pro",        0.17*kPi/180,.05,.03,true, 2,true, 0.40,true, .00,7.4},
        {"AI",         0.08*kPi/180,.02,.02,true, 2,true, 0.45,true, .00,7.8}}};
    return table[static_cast<size_t>(std::clamp(level,0,kLevels-1))];
}

/// A planned or executed stroke. `target`/`pocket` are the call (pocket -1 = none), `place` a cue-ball position for
/// ball in hand (used when `placed` is true).
struct Shot {
    double angle=0,speed=0,side=0,top=0;
    int target=-1,pocket=-1;
    bool safety=false,placed=false,valid=false;
    V2 place{};
    double potChance=0,value=-std::numeric_limits<double>::infinity();
};

/// splitmix64: tiny, seedable, identical on every platform (std::normal_distribution is not).
struct Random {
    std::uint64_t state;
    explicit Random(std::uint64_t seed):state(seed? seed:0x9E3779B97F4A7C15ULL){}
    std::uint64_t next(){std::uint64_t z=(state+=0x9E3779B97F4A7C15ULL);z=(z^(z>>30))*0xBF58476D1CE4E5B9ULL;z=(z^(z>>27))*0x94D049BB133111EBULL;return z^(z>>31);}
    double unit(){return (next()>>11)*(1.0/9007199254740992.0);}
    double normal(){double u=std::max(unit(),1e-12),v=unit();return std::sqrt(-2*std::log(u))*std::cos(2*kPi*v);}
};

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

/// Geometric ease of potting `object` into pocket `k` from `cue`: 0 (impossible) … ~1 (short, straight).
inline double ease(const World& w,V2 cue,const Ball& object,int k){
    const auto m=mouths(w.config);const double r=w.config.radius;
    const V2 toPocket=m[static_cast<size_t>(k)]-object.p;const double dp=toPocket.length();if(dp<1e-6)return 0;
    const V2 u=toPocket*(1/dp);const V2 ghost=object.p-u*(2*r);
    const V2 toGhost=ghost-cue;const double dc=toGhost.length();if(dc<1e-6)return 0;
    const double cut=(toGhost.x*u.x+toGhost.y*u.y)/dc;          // cos(cut angle)
    if(cut<0.26)return 0;                                       // thinner than ~75°
    if(std::abs(ghost.x)>w.config.width/2-r*.5||std::abs(ghost.y)>w.config.length/2-r*.5)return 0;
    if(!clearPath(w.balls,cue,ghost,0,object.id,r)||!clearPath(w.balls,object.p,m[static_cast<size_t>(k)],0,object.id,r))return 0;
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

/// Stroke speed that carries the object ball to the pocket with a little to spare (rolling resistance only; ASSUMED
/// margin, the simulation is the judge).
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

struct Candidate {int ball=-1,pocket=-1;double angle=0,speed=0,top=0,side=0,chance=0,value=0;Judgement outcome{};};

/// Scan aim offsets around the geometric line; returns the centre and angular width (rad) of the window that pots.
inline bool potWindow(const World& w,const match::State& s,int player,const Ball& object,int k,double geometric,double speed,double top,double& centre,double& width){
    // Throw/squirt can move the window ~1° off the ghost line.
    const double span=2.4*kPi/180;const int n=25;int first=-1,last=-1,run=0,bestFirst=-1,bestRun=0;
    for(int i=0;i<n;++i){
        const double a=geometric+span*(2.0*i/(n-1)-1);
        const Judgement j=judge(w,s,w.simulate(a,speed,0,top,25),player,object.id,k);
        if(j.potted&&!j.lost){if(run==0)first=i;++run;last=i;if(run>bestRun){bestRun=run;bestFirst=first;}}else run=0;
    }
    (void)last;
    if(bestRun==0)return false;
    const double step=2*span/(n-1);
    centre=geometric+span*(2.0*(bestFirst+(bestRun-1)/2.0)/(n-1)-1);
    width=bestRun*step;
    return true;
}
/// Chance that a normally distributed aim error stays inside a window of the given width.
inline double chanceInside(double width,double sigma){return sigma<=0?1:std::erf(width/(2*std::sqrt(2.0)*sigma));}

/// Cue-ball position for ball in hand: straight behind the easiest legal ball; behind the head string when required.
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
            const V2 u=d*(1/len);
            for(double back:{0.30,0.42,0.22,0.55}){
                const V2 p=b.p-u*(2*r+back);
                if(!free(p))continue;
                const double e=ease(w,p,b,k);
                if(e>bestEase){bestEase=e;best=p;}
            }
        }
    }
    if(bestEase>0)return best;
    for(double y:{-0.9,-0.72,-1.1,0.0,0.45,-0.45,0.9})for(double x:{0.0,-0.14,0.14,-0.28,0.28,-0.42,0.42}){V2 p{x,y};if(free(p))return p;}
    return best;
}

/// Plan a stroke (no hand error). `world` must be at rest with the cue ball already placed.
inline Shot plan(const World& world,const match::State& s,int level,std::uint64_t seed){
    Shot out;const Skill& k=skill(level);Random rng(seed^(0xA5A5ULL*static_cast<std::uint64_t>(level+1)));
    const int player=s.currentPlayer;
    const Ball* cue=find(world.balls,0);if(!cue)return out;
    const double r=world.config.radius;const auto m=mouths(world.config);

    if(s.breakShot){
        // Full hit on the apex/lowest ball; better players break harder and from the side.
        int apex=-1;double nearest=1e9;
        for(const auto& b:world.balls){if(b.sunk||b.id<=0)continue;const double d=(b.p-cue->p).length();if(d<nearest){nearest=d;apex=b.id;}}
        if(apex<0)return out;
        const Ball* a=find(world.balls,apex);
        out.angle=std::atan2(a->p.y-cue->p.y,a->p.x-cue->p.x);out.speed=k.breakSpeed;out.top=level>=3?0.15:0;
        out.target=apex;out.valid=true;out.value=0;return out;
    }

    std::vector<Candidate> pots;
    for(const auto& b:world.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player)||!wantedPot(s,world.balls,b.id,player))continue;
        for(int pk=0;pk<6;++pk){
            const double e=ease(world,cue->p,b,pk);if(e<=0)continue;
            const V2 toPocket=m[static_cast<size_t>(pk)]-b.p;const double dp=toPocket.length();const V2 u=toPocket*(1/dp);
            const V2 ghost=b.p-u*(2*r);const V2 line=ghost-cue->p;const double dc=line.length();
            const double geometric=std::atan2(line.y,line.x),cutCos=(line.x*u.x+line.y*u.y)/dc;
            std::vector<double> tops{0};if(k.usesSpin){tops.push_back(0.55);tops.push_back(-0.55);}
            std::vector<double> extras{0.6};if(k.lookahead>0){extras.push_back(1.3);}   // object ball runs 0.6 m past the pocket: a firm pot, not one dying in the jaws
            for(double top:tops)for(double extra:extras){
                Candidate c;c.ball=b.id;c.pocket=pk;c.top=top;c.speed=paceFor(world,dc,dp,cutCos,extra);
                double centre=geometric,width=0;
                if(k.centreWindow){
                    if(!potWindow(world,s,player,b,pk,geometric,c.speed,top,centre,width))continue;
                    c.chance=chanceInside(width,k.aimSigma);
                }else{
                    // Beginner: trusts the ghost ball; whether it drops is found out on the table.
                    c.chance=std::clamp(e*1.6,0.05,0.9);
                }
                c.angle=centre;c.outcome=judge(world,s,world.simulate(c.angle,c.speed,0,top,25),player,b.id,pk);
                if(c.outcome.lost)continue;
                if(k.centreWindow&&!c.outcome.potted)continue;
                double position=0;
                if(k.lookahead>0&&c.outcome.potted&&!c.outcome.won){
                    World after(world.config);after.reset(world.simulate(c.angle,c.speed,0,top,25).balls);
                    match::State next=s;next.breakShot=false;
                    position=offer(after,next,c.outcome.cue,player);
                    if(k.lookahead>1&&position<=0)position=-0.15;      // no shot afterwards hurts a strong player more
                }
                const double win=c.outcome.won?4.0:0;
                c.value=c.chance*(1.0+win+(k.lookahead>0?1.5*position:0))-(1-c.chance)*(k.lookahead>0?0.35:0.1);
                pots.push_back(c);
            }
        }
    }

    auto fill=[&](const Candidate& c,bool safety){
        out.angle=c.angle;out.speed=c.speed;out.top=c.top;out.side=c.side;out.target=c.ball;out.pocket=safety?-1:c.pocket;
        out.safety=safety;out.potChance=c.chance;out.value=c.value;out.valid=true;
    };
    const Candidate* bestPot=nullptr;
    for(const auto& c:pots)if(!bestPot||c.value>bestPot->value)bestPot=&c;
    if(bestPot&&k.blunder>0&&pots.size()>1&&rng.unit()<k.blunder){
        // Human-like mistake of choice: take another option, not the best one.
        const Candidate* other=&pots[static_cast<size_t>(rng.next()%pots.size())];
        if(other!=bestPot)bestPot=other;
    }
    const bool wantSafety=k.safetyBelow>0&&(!bestPot||bestPot->chance<k.safetyBelow);
    if(bestPot&&!wantSafety){fill(*bestPot,false);return out;}

    // Safety / escape: scan directions and speeds, keep the legal stroke that leaves the opponent least.
    if(k.safetyBelow>0||k.escapes||!bestPot){
        Candidate best;bool found=false;double bestScore=-1e9;
        const int directions=(k.escapes||!bestPot)?(level>=4?96:72):0;
        std::vector<double> angles;
        for(const auto& b:world.balls){
            if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
            const double base=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);
            for(double off:{0.0,0.012,-0.012,0.024,-0.024})angles.push_back(base+off);
        }
        for(int i=0;i<directions;++i)angles.push_back(2*kPi*i/directions);
        const std::vector<double> speeds=level>=3?std::vector<double>{1.1,1.9,2.8}:std::vector<double>{1.6,2.6};
        match::State next=s;next.breakShot=false;
        for(double a:angles)for(double v:speeds){
            const Outcome o=world.simulate(a,v,0,0,25);
            const Judgement j=judge(world,s,o,player,-1,-1);
            if(j.lost)continue;
            double score;
            if(j.foul)score=-2.0;
            else{
                World after(world.config);after.reset(o.balls);
                score=j.keepsTurn?0.6+offer(after,next,j.cue,player):-offer(after,next,j.cue,1-player);
            }
            if(score>bestScore){bestScore=score;found=true;best.angle=a;best.speed=v;best.ball=j.firstHit;best.pocket=-1;best.chance=0;best.value=score;}
        }
        // A weak pot is still better than a poor safety.
        if(found&&(!bestPot||bestScore>bestPot->value-0.25)){fill(best,true);return out;}
    }
    if(bestPot){fill(*bestPot,false);return out;}

    // Nothing better: roll at the nearest legal ball (a beginner's answer to a snooker).
    double nearest=1e9;
    for(const auto& b:world.balls){
        if(b.sunk||b.id<=0||!legalFirst(s,world.balls,b.id,player))continue;
        const double d=(b.p-cue->p).length();
        if(d<nearest){nearest=d;out.angle=std::atan2(b.p.y-cue->p.y,b.p.x-cue->p.x);out.target=b.id;}
    }
    if(nearest<1e9){out.speed=2.0;out.safety=true;out.valid=true;out.value=-1;}
    return out;
}

/// The stroke as the hand delivers it: planned stroke plus the level's execution error.
inline Shot execute(const Shot& planned,int level,std::uint64_t seed){
    Shot s=planned;if(!s.valid)return s;
    const Skill& k=skill(level);Random rng(seed^0x51ED270B0B5ULL);
    s.angle+=k.aimSigma*rng.normal();
    s.speed=std::clamp(s.speed*(1+k.speedSigma*rng.normal()),0.4,8.0);
    s.side=std::clamp(s.side+k.tipSigma*rng.normal(),-0.6,0.6);
    s.top=std::clamp(s.top+k.tipSigma*rng.normal(),-0.7,0.7);
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
