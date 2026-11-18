// 0.48 M1 "Máy quay": cổng giữ cho bộ lập kế hoạch máy quay (BankLab/Core/CameraPlanner.hpp).
// Năm cú ghi THẬT bằng mô phỏng (thẳng, cắt 30°, bank, kick, phá 9 bi) × các kiểu máy × khung 16:9 / 9:16.
// Đo như người xem: đồng hồ thật bước 1/240 s, đồng hồ bản ghi tiến theo rateAt (như Swift), lấy pose theo bản ghi.
//  - tốc độ góc hướng nhìn <= 90°/s, gia tốc góc <= 600°/s² trong cảnh (bỏ đúng cửa sổ chứa điểm cắt); mắt liên tục.
//  - bi chính nhìn thấy (tia mắt → tâm bi không bị bi khác, băng/gỗ, chụp đèn chặn) >= 95 % thời gian mỗi cảnh.
//  - mỗi cảnh >= 1,2 s thật; không cắt trong 0,3 s trước khoảnh khắc chính; luật 180° (camera::actionAxis).
//  - rate liên tục, |d rate/dt| <= 4/s, min >= 0,35; ngoài Đạo diễn/Teaser rate = 1.
//  - bi chính luôn trong vùng an toàn (cách mép >= 8 %: |NDC| <= 0,84) ở 16:9 và 9:16.
//  - Teaser startTime→endTime <= 6,5 s thật; Đạo diễn có lọt (không phá) = 6 cảnh.
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/Core/MatchRules.hpp"
#include "../BankLab/Core/CameraPlanner.hpp"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <string>
using namespace banklab;
namespace cam=banklab::camera;
using banklab::match::Rules;using banklab::match::Discipline;

static int fails=0,passes=0;
static void check(bool ok,const std::string& what){if(ok)++passes;else{++fails;std::cerr<<"FAIL: "<<what<<"\n";}}

struct Shot{std::string name;std::vector<Ball> balls;double angle=0,speed=0,side=0,top=0;cam::Recording rec;};

static cam::Recording record(const std::vector<Ball>& balls,double angle,double speed,double side,double top){
    World w;w.reset(balls);
    cam::Recording r;r.m=static_cast<int>(w.balls.size());for(auto& b:w.balls)r.ids.push_back(b.id);
    auto push=[&]{r.times.push_back(w.time);for(auto& b:w.balls){r.xs.push_back(b.p.x);r.ys.push_back(b.p.y);r.sunk.push_back(b.sunk?1:0);}};
    push();w.strike(angle,speed,side,top);
    for(int n=1;n<960*25;++n){w.step();if(n%8==0)push();if(!w.moving()){push();break;}}
    for(auto& e:w.events)r.events.push_back({e.kind,e.a,e.b,e.time,e.p.x,e.p.y,e.impact});
    return r;
}
static const cam::RecEvent* firstEvent(const cam::Recording& r,int kind,int ball){
    for(auto& e:r.events)if(e.kind==kind&&(e.a==ball||(kind==1&&e.b==ball)))return &e;
    return nullptr;
}
static bool cueSunk(const cam::Recording& r){for(auto& e:r.events)if(e.kind==2&&e.a==0)return true;return false;}
// First cue-ball event (cushion or ball).
static const cam::RecEvent* firstCueEvent(const cam::Recording& r){for(auto& e:r.events)if((e.kind==0&&e.a==0)||(e.kind==1&&(e.a==0||e.b==0)))return &e;return nullptr;}

static Ball ball(int id,double x,double y){Ball b;b.id=id;b.p={x,y};return b;}

// Straight / cut: search a small aim correction (throw, like a player) for a clean pot of ball 1 in `pocket`.
static bool findPot(Shot& s,int pocket,bool wantCushionFirst,double span,double step){
    for(double off=0;off<=span;off+=step)for(int sg:{1,-1}){
        const double a=s.angle+sg*off;auto r=record(s.balls,a,s.speed,s.side,s.top);
        const auto* c=firstCueEvent(r);const auto* p=firstEvent(r,2,1);
        if(!c||c->kind!=1||!p||p->b!=pocket||cueSunk(r))continue;
        const auto* cu=firstEvent(r,0,1);const bool cushionBefore=cu&&cu->time<p->time;
        if(cushionBefore!=wantCushionFirst)continue;
        s.angle=a;s.rec=r;return true;
    }
    return false;
}

static std::vector<Shot> shots(){
    std::vector<Shot> out;const double R=.028575;
    {   // 1 · thẳng vào lỗ góc xa
        Shot s;s.name="thang";const V2 cue{0,-.25},hole{.67,1.305};const V2 d=(hole-cue).unit();const V2 ob=cue+d*.85;
        s.balls={ball(0,cue.x,cue.y),ball(1,ob.x,ob.y)};s.angle=std::atan2(d.y,d.x);s.speed=2.2;
        check(findPot(s,5,false,.03,.0005),"straight shot pots ball 1 in pocket 5");out.push_back(s);
    }
    {   // 2 · cắt 30°
        Shot s;s.name="cat30";const V2 q{-.25,.55},hole{-.67,1.305};const V2 u=(hole-q).unit();const V2 g=q-u*(2*R);
        const double c=std::cos(30*cam::kPi/180),sn=std::sin(30*cam::kPi/180);const V2 ru{c*u.x-sn*u.y,sn*u.x+c*u.y};
        const V2 cue=g-ru*.75;const V2 aim=(g-cue).unit();
        s.balls={ball(0,cue.x,cue.y),ball(1,q.x,q.y)};s.angle=std::atan2(aim.y,aim.x);s.speed=2.4;
        check(findPot(s,4,false,.06,.0005),"30 degree cut pots ball 1 in pocket 4");
        // measured cut angle: cue aim vs object-ball departure
        const auto* e=firstEvent(s.rec,1,1);
        if(e){const auto& r=s.rec;int k=r.frameBelow(e->time+.06);const int j=r.col(1);
            const double dx=r.xs[static_cast<std::size_t>(k*r.m+j)]-q.x,dy=r.ys[static_cast<std::size_t>(k*r.m+j)]-q.y;
            double cut=std::abs(std::remainder(std::atan2(dy,dx)-s.angle,2*cam::kPi))*180/cam::kPi;
            check(cut>24&&cut<36,"cut shot is ~30 degrees ("+std::to_string(cut)+")");}
        out.push_back(s);
    }
    {   // 3 · bank: bi mục tiêu dội 1 băng rồi vào lỗ
        Shot s;s.name="bank";const V2 cue{-.1,-.75},q{.30,-.10};
        s.balls={ball(0,cue.x,cue.y),ball(1,q.x,q.y)};bool ok=false;
        const double base=std::atan2(q.y-cue.y,q.x-cue.x);
        for(double sp:{2.6,3.2,2.0})for(double off=-.045;off<=.045&&!ok;off+=.0015){
            auto r=record(s.balls,base+off,sp,0,0);
            const auto* c=firstCueEvent(r);const auto* p=firstEvent(r,2,1);const auto* cu=firstEvent(r,0,1);
            if(c&&c->kind==1&&p&&p->b>=0&&cu&&cu->time<p->time&&!cueSunk(r)){
                int rails=0;for(auto& e:r.events)if(e.kind==0&&e.a==1&&e.time<p->time)++rails;
                if(rails==1){s.angle=base+off;s.speed=sp;s.rec=r;ok=true;}
            }
            if(ok)break;
        }
        check(ok,"bank shot found: object ball one cushion then pocket");out.push_back(s);
    }
    {   // 4 · kick: bi cái chạm băng trước rồi tới bi
        Shot s;s.name="kick";const V2 cue{.25,-.70},q{-.20,.45};
        s.balls={ball(0,cue.x,cue.y),ball(1,q.x,q.y)};bool ok=false;
        for(double sp:{2.6,3.2})for(double a=-.2;a<1.6&&!ok;a+=.003){
            auto r=record(s.balls,a,sp,0,0);const auto* c=firstCueEvent(r);
            if(!c||c->kind!=0)continue;
            const auto* hit=firstEvent(r,1,1);if(!hit||cueSunk(r))continue;
            bool onlyOneRail=true;for(auto& e:r.events)if(e.kind==0&&e.a==0&&e.time<hit->time&&e.time>c->time+1e-9)onlyOneRail=false;
            if(onlyOneRail){s.angle=a;s.speed=sp;s.rec=r;ok=true;}
        }
        check(ok,"kick shot found: cue ball cushion first, then object ball");out.push_back(s);
    }
    {   // 5 · phá 9 bi
        Shot s;s.name="pha";Rules rules(Discipline::NineBall);s.balls=rules.rack(7);s.balls[0].p={.02,-.90};
        V2 h{0,1e9};for(auto& b:s.balls)if(b.id!=0&&b.p.y<h.y)h=b.p;
        s.angle=std::atan2(h.y-s.balls[0].p.y,h.x-s.balls[0].p.x);s.speed=8;s.top=-.2;
        s.rec=record(s.balls,s.angle,s.speed,0,s.top);
        int moved=0;for(int j=0;j<s.rec.m;++j){const double dx=s.rec.xs[static_cast<std::size_t>((s.rec.n()-1)*s.rec.m+j)]-s.rec.xs[static_cast<std::size_t>(j)],dy=s.rec.ys[static_cast<std::size_t>((s.rec.n()-1)*s.rec.m+j)]-s.rec.ys[static_cast<std::size_t>(j)];if(std::hypot(dx,dy)>.02||s.rec.sunk[static_cast<std::size_t>((s.rec.n()-1)*s.rec.m+j)])++moved;}
        check(moved>=5,"break moves at least 5 balls");out.push_back(s);
    }
    {   // 6 · cú rất ngắn (bản ghi < 1,5 s): cảnh phải gộp mà vẫn hợp lệ
        Shot s;s.name="ngan";s.balls={ball(0,.1,.2),ball(1,.1,.27),ball(2,-.3,.6)};s.angle=cam::kPi/2;s.speed=.3;
        s.rec=record(s.balls,s.angle,s.speed,0,0);
        check(s.rec.times.back()<1.5,"short shot record < 1.5 s ("+std::to_string(s.rec.times.back())+")");out.push_back(s);
    }
    return out;
}

struct Sample{double t,w,rate;int scene;int subject;cam::Pose p;};

static const char* styleName(cam::Style s){
    switch(s){case cam::Style::Director:return"Director";case cam::Style::Learn:return"Learn";case cam::Style::Shooter:return"Shooter";
    case cam::Style::Wide34:return"Wide34";case cam::Style::Overhead:return"Overhead";case cam::Style::FollowCue:return"FollowCue";
    case cam::Style::RailSide:return"RailSide";case cam::Style::PocketMeet:return"PocketMeet";case cam::Style::Teaser:return"Teaser";}
    return"?";
}

static void evaluate(const Shot& shot,cam::Style style,double aspect,double lead=cam::Planner::recommendedLead,double tail=cam::Planner::recommendedTail){
    cam::Planner plan(shot.rec,shot.angle,style,aspect,lead,tail);
    const auto& rec=plan.recording();
    const std::string tag=shot.name+"/"+styleName(style)+(aspect>1?"/16:9":"/9:16")+(lead<cam::Planner::recommendedLead?"/lead1":"");
    const bool directed=style==cam::Style::Director||style==cam::Style::Teaser;
    // Walk the playback clock like the app: wall step h, record clock advances by rate (RK2).
    const double h=1.0/240;std::vector<Sample> S;double t=plan.startTime(),w=0;
    while(t<plan.endTime()&&S.size()<400000){
        S.push_back({t,w,plan.rate(t),plan.sceneIndex(t),plan.subjectColumn(t),plan.pose(t)});
        const double r1=plan.rate(t),r2=plan.rate(t+.5*h*r1);t+=h*r2;w+=h;
    }
    check(S.size()>10,tag+": playback has samples");
    if(style==cam::Style::Teaser)check(w<=cam::Limits::teaserMax+h,tag+": teaser wall duration "+std::to_string(w)+" <= 6.5 s");
    check(std::abs(w-plan.wallDuration)<.02+h,tag+": wallDuration matches integrated 1/rate");
    // rate
    double minRate=9,maxSlope=0,maxRate=0;bool unit=true;
    for(std::size_t i=0;i+1<S.size();++i){minRate=std::min(minRate,S[i].rate);maxRate=std::max(maxRate,S[i].rate);maxSlope=std::max(maxSlope,std::abs(S[i+1].rate-S[i].rate)/h);if(std::abs(S[i].rate-1)>1e-12)unit=false;}
    check(minRate>=cam::Limits::minRate-1e-9,tag+": rate >= 0.35");
    check(maxSlope<=cam::Limits::maxRateSlope,tag+": |d rate/dt| "+std::to_string(maxSlope)+" <= 4/s");
    if(!directed)check(unit,tag+": rate = 1 outside Director/Teaser");
    // angular speed / acceleration / eye continuity, inside scenes
    double peakW=0,peakA=0,maxJump=0;std::vector<double> ws;
    auto dir=[](const cam::Pose& p){return cam::unit(p.target-p.eye);};
    cam::V3 prevOmega{};bool havePrev=false;
    for(std::size_t i=0;i+1<S.size();++i){
        if(S[i].scene!=S[i+1].scene){havePrev=false;continue;}
        const double dt=S[i+1].w-S[i].w;if(dt<=1e-9)continue;
        const cam::V3 d0=dir(S[i].p),d1=dir(S[i+1].p),c=cam::cross(d0,d1);
        const double ang=std::atan2(cam::len(c),cam::dot(d0,d1));const cam::V3 om=cam::unit(c)*(ang/dt*cam::kDeg);
        peakW=std::max(peakW,cam::len(om));ws.push_back(cam::len(om));
        if(havePrev){const double a=cam::len(om-prevOmega)/dt;if(a>peakA&&std::getenv("CAMDEBUG"))std::printf("    accel %.0f at t=%.4f w=%.3f scene %d rate %.3f\n",a,S[i].t,S[i].w,S[i].scene,S[i].rate);peakA=std::max(peakA,a);}
        prevOmega=om;havePrev=true;
        maxJump=std::max(maxJump,cam::len(S[i+1].p.eye-S[i].p.eye)/dt);
    }
    std::sort(ws.begin(),ws.end());const double p95=ws.empty()?0:ws[static_cast<std::size_t>(.95*static_cast<double>(ws.size()-1))];
    check(peakW<=cam::Limits::maxAngularSpeed,tag+": peak angular speed "+std::to_string(peakW)+" <= 90 deg/s");
    check(peakA<=cam::Limits::maxAngularAccel,tag+": peak angular accel "+std::to_string(peakA)+" <= 600 deg/s2");
    check(maxJump<=10,tag+": eye continuous inside scenes (max "+std::to_string(maxJump)+" m/s)");
    // per-scene visibility, safe frame, durations
    const int scenes=static_cast<int>(plan.sceneList().size());
    std::vector<int> seen(static_cast<std::size_t>(scenes),0),tot(static_cast<std::size_t>(scenes),0),count(static_cast<std::size_t>(scenes),0);
    int unsafe=0,checked=0;double worstNdc=0;
    for(auto& s:S){
        ++count[static_cast<std::size_t>(s.scene)];
        if(s.subject<0||rec.sunkAt(s.subject,s.t))continue;
        ++tot[static_cast<std::size_t>(s.scene)];if(cam::ballVisible(rec,s.subject,s.t,s.p.eye))++seen[static_cast<std::size_t>(s.scene)];
        double nx=0,ny=0;++checked;
        if(!cam::project(s.p,aspect,rec.pos(s.subject,s.t),nx,ny)){++unsafe;continue;}
        worstNdc=std::max(worstNdc,std::max(std::abs(nx),std::abs(ny)));
        if(std::abs(nx)>1-2*cam::Limits::safeMargin||std::abs(ny)>1-2*cam::Limits::safeMargin)++unsafe;
    }
    double minVis=1;
    for(int i=0;i<scenes;++i){
        const double v=tot[static_cast<std::size_t>(i)]?static_cast<double>(seen[static_cast<std::size_t>(i)])/tot[static_cast<std::size_t>(i)]:1;minVis=std::min(minVis,v);
        check(v>=cam::Limits::minVisible,tag+": scene "+std::to_string(i)+" subject visible "+std::to_string(v));
        if(directed)check(count[static_cast<std::size_t>(i)]*h>=cam::Limits::minScene-h,tag+": scene "+std::to_string(i)+" lasts "+std::to_string(count[static_cast<std::size_t>(i)]*h)+" s >= 1.2 s");
    }
    check(unsafe==0,tag+": subject inside 8% safe area ("+std::to_string(unsafe)+"/"+std::to_string(checked)+" out, worst |ndc| "+std::to_string(worstNdc)+")");
    if(directed){
        // key moments in wall time
        auto wallOf=[&](double tk){for(std::size_t i=0;i+1<S.size();++i)if(S[i+1].t>=tk)return S[i].w+(tk-S[i].t)/std::max(1e-12,S[i+1].t-S[i].t)*(S[i+1].w-S[i].w);return S.back().w;};
        std::vector<double> keys{wallOf(0)};
        if(std::isfinite(plan.contactTime))keys.push_back(wallOf(plan.contactTime));
        if(std::isfinite(plan.potTime))keys.push_back(wallOf(plan.potTime));
        for(std::size_t i=0;i+1<S.size();++i)if(S[i].scene!=S[i+1].scene){
            const double wc=S[i+1].w;
            for(double K:keys)check(!(wc>K-cam::Limits::preCut+h&&wc<K-h),tag+": cut at "+std::to_string(wc)+" not within 0.3 s before key moment "+std::to_string(K));
            const cam::Axis ax=cam::actionAxis(rec,S[i+1].t,plan.aimAngle());
            const double a=cam::axisSide(ax,S[i].p.eye),b=cam::axisSide(ax,S[i+1].p.eye);
            check(cam::sameSide180(a,b),tag+": 180-degree rule at cut "+std::to_string(i)+" ("+std::to_string(a)+" vs "+std::to_string(b)+")");
        }
        if(style==cam::Style::Director&&plan.potCol>=0&&!plan.isBreak&&lead>=cam::Planner::recommendedLead)check(scenes==6,tag+": Director has 6 scenes with a pot (got "+std::to_string(scenes)+")");
        if(plan.isBreak){bool bw=false;for(auto& s:plan.sceneList())if(s.kind==cam::SceneKind::BreakWide)bw=true;check(bw,tag+": break uses the wide break scene");}
        // trail reveal: 0 before Wrap, 1 at the end
        check(plan.trailReveal(plan.endTime())==1,tag+": trail fully revealed at the end");
        check(plan.trailReveal(plan.startTime())==0,tag+": trail hidden at the start");
    }
    if(style==cam::Style::Learn){double prev=-1;bool mono=true;for(auto& s:S){const double r=plan.trailReveal(s.t);if(r<prev-1e-12)mono=false;prev=r;}check(mono&&plan.trailReveal(plan.endTime())==1,tag+": learn trail reveals progressively");}
    check(plan.bestStill>=0&&plan.bestStill<=rec.times.back(),tag+": best still inside the recording");
    std::string kinds;for(auto& s:plan.sceneList())kinds+=std::to_string(static_cast<int>(s.kind));
    std::printf("  %-26s scenes %d [%s] wall %.2f s  peak %.1f p95 %.1f deg/s  accel %.0f  minVis %.3f  ndc %.2f\n",tag.c_str(),scenes,kinds.c_str(),w,peakW,p95,peakA,minVis,worstNdc);
}

int main(){
    auto list=shots();
    for(auto& s:list){
        if(s.rec.n()==0)continue;
        // the recorded events are of the right kind
        const auto* c=firstCueEvent(s.rec);
        if(s.name=="kick")check(c&&c->kind==0,"kick: cue ball hits a cushion first");
        else check(c&&c->kind==1,s.name+": cue ball hits a ball first");
        if(s.name=="bank"){const auto* p=firstEvent(s.rec,2,1);const auto* cu=firstEvent(s.rec,0,1);check(p&&cu&&cu->time<p->time,"bank: cushion before pot");}
        std::printf("%s: %d frames, %.2f s, %zu events\n",s.name.c_str(),s.rec.n(),s.rec.times.back(),s.rec.events.size());
        for(auto st:{cam::Style::Director,cam::Style::Teaser,cam::Style::FollowCue,cam::Style::RailSide,cam::Style::PocketMeet,cam::Style::Learn,cam::Style::Overhead})
            for(double a:{16.0/9,9.0/16})evaluate(s,st,a);
        // short lead/tail (app passes less than recommended): scenes merge, every rule still holds
        for(auto st:{cam::Style::Director,cam::Style::Teaser})evaluate(s,st,16.0/9,1.0,.5);
        for(auto st:{cam::Style::Shooter,cam::Style::Wide34}){   // static manual angles: sane poses, rate 1
            cam::Planner p(s.rec,s.angle,st,16.0/9,cam::Planner::recommendedLead,cam::Planner::recommendedTail);
            bool ok=true;for(double t=p.startTime();t<p.endTime();t+=.05){auto q=p.pose(t);ok=ok&&std::isfinite(q.eye.x)&&std::isfinite(q.fov)&&q.fov>=20&&q.fov<=80&&p.rate(t)==1;}
            check(ok,s.name+"/"+styleName(st)+": finite poses, rate 1");
        }
    }
    if(fails){std::cerr<<"FAIL CameraPlanner: "<<fails<<" of "<<(fails+passes)<<"\n";return 1;}
    std::cout<<"PASS CameraPlanner: "<<passes<<" checks (5 shots + very short shot x 7 styles x 2 aspects + static styles)\n";
}
