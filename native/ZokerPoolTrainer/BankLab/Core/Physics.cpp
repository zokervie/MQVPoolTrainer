#include "CushionContact3D.hpp"
#include "Physics.hpp"
namespace banklab {
namespace {
// Solid-sphere impulse algebra. Original implementation; not copied from pooltool.
struct V3 {
    double x,y,z;
    V3 operator+(V3 b)const{return{x+b.x,y+b.y,z+b.z};}
    V3 operator-(V3 b)const{return{x-b.x,y-b.y,z-b.z};}
    V3 operator*(double f)const{return{x*f,y*f,z*f};}
    double dot(V3 b)const{return x*b.x+y*b.y+z*b.z;}
    V3 cross(V3 b)const{return{y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x};}
    double length()const{return std::sqrt(dot(*this));}
};
V3 capped(V3 v,double limit){double l=v.length();return l>limit&&l>0?v*(limit/l):v;}
void rotate(Ball&b,V3 angular,double dt){
    double speed=angular.length();if(speed<1e-12)return;
    double half=speed*dt*.5,scale=std::sin(half)/speed;
    Rotation d{angular.x*scale,angular.y*scale,angular.z*scale,std::cos(half)},q=b.rotation;
    Rotation n{d.w*q.x+d.x*q.w+d.y*q.z-d.z*q.y,
               d.w*q.y-d.x*q.z+d.y*q.w+d.z*q.x,
               d.w*q.z+d.x*q.y-d.y*q.x+d.z*q.w,
               d.w*q.w-d.x*q.x-d.y*q.y-d.z*q.z};
    double length=std::sqrt(n.x*n.x+n.y*n.y+n.z*n.z+n.w*n.w);
    b.rotation={n.x/length,n.y/length,n.z/length,n.w/length};
}
}

void World::buildRails(){
    segments.clear();double x=config.width/2,y=config.length/2;
    // Standard pool reference: mouth is measured tip-to-tip, not hole diameter.
    double c=.1143/std::sqrt(2.0),g=.127/2,d=.065;
    auto add=[&](V2 a,V2 b,int n){segments.push_back({a,b,n});};
    for(int s:{-1,1}){
        int r=s<0?0:1;
        add({s*x,-y+c},{s*x,-g},r);add({s*x,g},{s*x,y-c},r);
        add({s*x,-y+c},{s*(x+d),-y+c-d*std::tan(52*pi/180)},r);add({s*x,y-c},{s*(x+d),y-c+d*std::tan(52*pi/180)},r);
        add({s*x,-g},{s*(x+d),-g+d*std::tan(14*pi/180)},r);add({s*x,g},{s*(x+d),g-d*std::tan(14*pi/180)},r);
        r=s<0?2:3;
        add({-x+c,s*y},{x-c,s*y},r);
        add({-x+c,s*y},{-x+c-d*std::tan(52*pi/180),s*(y+d)},r);add({x-c,s*y},{x-c+d*std::tan(52*pi/180),s*(y+d)},r);
    }
}
void World::strike(double angle,double speed,double side,double top){
    if(!std::isfinite(angle)||!std::isfinite(speed)||!std::isfinite(side)||!std::isfinite(top))return;
    if(config.experimental3D){strikeElevated(angle,speed,side,top);return;}
    if(moving())return;
    auto it=std::find_if(balls.begin(),balls.end(),[](const Ball&b){return b.id==0;});
    if(it==balls.end()||it->sunk)return;
    side=std::clamp(side,-.7,.7);top=std::clamp(top,-.7,.7);
    double mag=std::hypot(side,top);if(mag>.7){side*=.7/mag;top*=.7/mag;}
    speed=std::clamp(speed,0.0,6.0);
    // TP A.30: cùng tốc độ cơ, đánh lệch tâm → bi chậm hơn. `speed` là tốc độ bi khi đánh tâm.
    const double k=1+config.mass/config.cueMass();
    speed*=k/(k+2.5*(side*side+top*top));
    // Impulse at an offset cue contact, solid-sphere I=2/5 mR².
    it->spin=-2.5*side*speed/config.radius;
    // TP A.31: squirt — bi lệch ngược phía effect, tức cùng chiều quay với ω_z (hệ phải, z lên).
    const double a=angle+std::copysign(squirtAngle(side,config.mass,config.cueEndMass()),it->spin);
    V2 d{std::cos(angle),std::sin(angle)},dv{std::cos(a),std::sin(a)};
    it->v=dv*speed;it->w=d.perp()*(2.5*top*speed/config.radius);
    for(auto&b:balls)b.rails=0;
    events.clear();time=0;accumulator=0;
}
double World::squirtAngle(double side,double m,double me){
    const double s=std::clamp(std::abs(side),0.0,1.0),c=1-s*s;
    if(s<1e-12||me<=0)return 0;
    return std::atan(2.5*s*std::sqrt(c)/(1+m/me+2.5*c));
}
bool World::moving()const{
    for(const auto&b:balls)if(!b.sunk&&(b.height>1e-7||std::abs(b.vertical)>1e-5||b.v.length()>1e-5||b.w.length()>1e-4||std::abs(b.spin)>1e-4))return true;
    return false;
}
void World::advance(double elapsed){
    // Catch up at most 100 ms; background/resume must not teleport balls.
    accumulator+=std::clamp(elapsed,0.0,.1);
    while(accumulator+1e-12>=stepSize){step();accumulator-=stepSize;}
}
void World::cloth(Ball&b,double dt){
    if(b.sunk)return;
    double r=config.radius,g=9.81;
    double remain=dt;
    V2 slip=b.v+b.w.perp()*r;
    if(slip.length()>1e-8&&config.sliding>0){
        double duration=std::min(remain,slip.length()/(3.5*config.sliding*g));
        V2 acc=slip.unit()*(-config.sliding*g);
        b.p+=b.v*duration+acc*(.5*duration*duration);
        b.v+=acc*duration;b.w+=acc.perp()*(-2.5*duration/r);
        remain-=duration;
    }else if(slip.length()>1e-8){b.p+=b.v*remain;remain=0;}
    if(remain>1e-12){
        double speed=b.v.length();
        if(speed>1e-10){
            V2 dir=b.v/speed;double dec=config.rolling*g;
            double duration=dec>0?std::min(remain,speed/dec):remain;
            b.p+=b.v*duration-dir*(.5*dec*duration*duration);
            b.v=dir*std::max(0.0,speed-dec*duration);
        }else b.v={};
        b.w=b.v.perp()/r;
    }
    double z=std::max(0.0,std::abs(b.spin)-config.spinDecay*dt);
    b.spin=std::copysign(z,b.spin);
}
void World::ballCollision(Ball&a,Ball&b){
    if(a.sunk||b.sunk)return;
    V2 delta=b.p-a.p;double len=delta.length(),diam=2*config.radius;
    if(len>diam+1e-9)return;
    V2 n=len>1e-10?delta/len:V2{1,0};
    double vn=(b.v-a.v).dot(n);
    double penetration=std::max(0.0,diam-len);
    a.p-=n*(penetration*.5+1e-9);b.p+=n*(penetration*.5+1e-9);
    if(vn>=0)return;
    double jn=-(1+config.ballRestitution)*vn*.5; // impulse divided by mass
    V3 normal{n.x,n.y,0};
    V3 wa{a.w.x,a.w.y,a.spin},wb{b.w.x,b.w.y,b.spin};
    V3 relative{b.v.x-a.v.x,b.v.y-a.v.y,0};
    V3 slip=relative-(wa+wb).cross(normal*config.radius);
    V3 tangent=slip-normal*slip.dot(normal);
    // Two solid spheres: tangential inverse effective mass is 7/m. μ theo tốc độ trượt (TP A.14).
    V3 friction=capped(tangent*(-1.0/7.0),config.ballFrictionAt(tangent.length())*jn);
    V3 impulse=normal*jn+friction;
    a.v-=V2{impulse.x,impulse.y};b.v+=V2{impulse.x,impulse.y};
    V3 dw=normal.cross(impulse)*(-2.5/config.radius);
    a.w+=V2{dw.x,dw.y};b.w+=V2{dw.x,dw.y};
    a.spin+=dw.z;b.spin+=dw.z;
    // Vertical velocity from tangential impulse is discarded by the planar constraint.
    events.push_back({1,a.id,b.id,time,(a.p+b.p)*.5,std::abs(vn)});
}
void World::railCollision(Ball&b,const Segment&s){
    if(b.sunk)return;
    V2 line=s.b-s.a;
    double f=std::clamp((b.p-s.a).dot(line)/line.dot(line),0.0,1.0);
    V2 q=s.a+line*f,delta=b.p-q;double len=delta.length(),rho=config.railRadius();
    if(len>rho+1e-9||len<1e-10)return;
    V2 n=delta/len;
    b.p+=n*(std::max(0.0,rho-len)+1e-9);
    if(b.v.dot(n)>=0)return;
    const double impact=std::abs(b.v.dot(n));
    cushionResponse(b,config,n,s.rail);
    b.rails++;events.push_back({0,b.id,s.rail,time,q,impact});
}
void World::cushionResponse(Ball&b,const Config&config,V2 n,int rail){
    const double r=config.radius;
    if(config.coupledCushions){
        const double h=std::clamp((config.railNoseHeightMeters()-r-b.height)/r,-.999,.999),c=std::sqrt(1-h*h);
        contact3d::Vec normal{n.x*c,n.y*c,-h};
        const double vn=contact3d::Vec{b.v.x,b.v.y,b.vertical}.dot(normal);
        const double e=std::clamp(config.bounce(rail)-config.railSpeedSensitivity*std::abs(vn),.4,.98);
        auto out=contact3d::solve({b.v.x,b.v.y,b.vertical},{b.w.x,b.w.y,b.spin},normal,r,e,config.grip(rail),config.slateFriction,b.height<=1e-8&&b.vertical<=1e-6);
        b.v={out.velocity.x,out.velocity.y};b.vertical=out.velocity.z;b.w={out.omega.x,out.omega.y};b.spin=out.omega.z;return;
    }
    // The contact normal points inward and downward from the raised rail nose.
    // Contact lever is radial, so normal impulse cannot create an arbitrary torque.
    double h=std::clamp(config.railHeight,0.0,.5),horizontal=std::sqrt(1-h*h);
    V3 normal{n.x*horizontal,n.y*horizontal,-h};
    V3 arm=normal*(-r),velocity{b.v.x,b.v.y,0},omega{b.w.x,b.w.y,b.spin};
    V3 contact=velocity+omega.cross(arm);
    double vn=contact.dot(normal);
    if(vn>=0)return;
    double restitution=config.railSpeedSensitivity>0
        ? std::clamp(config.bounce(rail)-config.railSpeedSensitivity*std::abs(vn),.4,.98)
        : config.bounce(rail);
    double jn=-(1+restitution)*vn;
    V3 slip=contact-normal*vn;
    // One solid sphere against a fixed surface: inverse tangential mass is 3.5/m.
    V3 friction=capped(slip*(-1.0/3.5),config.grip(rail)*jn);
    V3 impulse=normal*jn+friction;
    V3 after=velocity+impulse;
    V3 angular=omega+arm.cross(impulse)*(2.5/(r*r));
    b.v={after.x,after.y};b.w={angular.x,angular.y};b.spin=angular.z;
    // The table constraint absorbs the vertical component; jumps are not simulated.
}
bool World::pocket(Ball&b){
    if(b.sunk)return true;
    double x=config.width/2,y=config.length/2;
    std::array<V2,6> holes={V2{-x-.035,-y-.035},V2{x+.035,-y-.035},V2{-x-.071,0},V2{x+.071,0},V2{-x-.035,y+.035},V2{x+.035,y+.035}};
    for(int i=0;i<6;i++){
        double rad=(i==2||i==3)?.058:.066;
        if((b.p-holes[i]).length()<rad){const double impact=b.v.length();b.sunk=true;b.v={};b.w={};b.spin=0;events.push_back({2,b.id,i,time,b.p,impact});return true;}
    }
    // Safety recovery beyond the catch basins; counted separately from a made pocket.
    if(std::abs(b.p.x)>x+.24||std::abs(b.p.y)>y+.24){const double impact=b.v.length();b.sunk=true;b.v={};b.w={};b.spin=0;events.push_back({2,b.id,-1,time,b.p,impact});return true;}
    return false;
}
void World::step(double dt){
    previousPresentation=balls;presentationEventCount=events.size();
    if(config.experimental3D||config.coupledCushions){stepElevated(dt);return;}
    // Within each fixed step, stop at the first swept sphere/capsule contact.
    // Prevents a 6 m/s ball being several millimetres overlapped before its cut normal is evaluated.
    auto sphereTime=[](V2 p,V2 v,double radius,double limit){
        double c=p.dot(p)-radius*radius,a=v.dot(v),pv=p.dot(v);
        if(a<1e-16||pv>=-1e-12)return limit;
        if(c<=0)return 0.0;
        double disc=pv*pv-a*c;if(disc<0)return limit;
        double t=(-pv-std::sqrt(disc))/a;
        return t>=0&&t<limit?t:limit;
    };
    auto evolve=[&](double t){
        for(auto&b:balls){
            if(b.sunk)continue;
            V3 before{b.w.x,b.w.y,b.spin};cloth(b,t);
            V3 after{b.w.x,b.w.y,b.spin};rotate(b,(before+after)*.5,t);
        }
        time+=t;
    };
    double remain=dt;
    for(int contact=0;remain>1e-12&&contact<32;++contact){
        double first=remain;
        for(size_t i=0;i<balls.size();++i){
            const auto&a=balls[i];if(a.sunk)continue;
            for(size_t j=i+1;j<balls.size();++j){
                const auto&b=balls[j];if(b.sunk)continue;
                first=sphereTime(b.p-a.p,b.v-a.v,2*config.radius,first);
            }
            for(const auto&s:segments){
                V2 edge=s.b-s.a;double length=edge.length();if(length<1e-12)continue;
                V2 tangent=edge/length,n=tangent.perp();double radius=config.railRadius();
                double distance=(a.p-s.a).dot(n),vn=a.v.dot(n);
                for(int sign:{-1,1}){
                    if(vn*sign>=-1e-12)continue;
                    double t=(sign*radius-distance)/vn;
                    if(t<0||t>=first)continue;
                    double along=(a.p+a.v*t-s.a).dot(tangent);
                    if(along>=0&&along<=length)first=t;
                }
                first=sphereTime(a.p-s.a,a.v,radius,first);
                first=sphereTime(a.p-s.b,a.v,radius,first);
            }
        }
        double elapsed=std::min(remain,std::max(first,1e-7));
        evolve(elapsed);remain-=elapsed;
        // Resolve contacts before testing a pocket, so a grazing jaw cannot be swallowed early.
        for(size_t i=0;i<balls.size();i++)for(size_t j=i+1;j<balls.size();j++)ballCollision(balls[i],balls[j]);
        for(auto&b:balls)for(const auto&s:segments)railCollision(b,s);
        for(auto&b:balls)pocket(b);
    }
    if(remain>1e-12){evolve(remain);for(auto&b:balls)pocket(b);}
}
std::vector<Ball> World::presentation()const{
 if(previousPresentation.size()!=balls.size()||presentationEventCount!=events.size()||!moving())return balls;
 auto out=balls;const double t=std::clamp(accumulator/stepSize,0.,1.);
 for(size_t i=0;i<out.size();i++){const auto&a=previousPresentation[i];const auto&b=balls[i];if(a.id!=b.id||a.sunk||b.sunk)continue;
 out[i].p=a.p+(b.p-a.p)*t;out[i].height=a.height+(b.height-a.height)*t;
 Rotation q=b.rotation;const auto&p=a.rotation;double dot=p.x*q.x+p.y*q.y+p.z*q.z+p.w*q.w;double sign=dot<0?-1:1;
 Rotation blend{p.x*(1-t)+q.x*t*sign,p.y*(1-t)+q.y*t*sign,p.z*(1-t)+q.z*t*sign,p.w*(1-t)+q.w*t*sign};
 double norm=std::sqrt(blend.x*blend.x+blend.y*blend.y+blend.z*blend.z+blend.w*blend.w);
 if(norm>1e-12)out[i].rotation={blend.x/norm,blend.y/norm,blend.z/norm,blend.w/norm};
 }return out;
}
double World::energy(const Ball&b,const Config&c){return c.mass*9.81*b.height+.5*c.mass*(b.v.dot(b.v)+b.vertical*b.vertical)+.2*c.mass*c.radius*c.radius*(b.w.dot(b.w)+b.spin*b.spin);}
std::vector<PredictionSample> World::predict(double angle,double speed,double side,double top,double seconds)const{
    World preview(config);
    preview.reset(balls);
    preview.strike(angle,speed,side,top);
    std::vector<PredictionSample> result;
    auto sample=[&](){for(const auto&b:preview.balls)if(b.id==0||b.id==1)result.push_back({b.id,preview.time,b.p,b.sunk,b.height});};
    sample();
    const int limit=static_cast<int>(std::clamp(seconds,0.0,20.0)/stepSize);
    for(int i=0;i<limit&&preview.moving();++i){
        preview.step();
        if((i+1)%32==0||!preview.moving())sample();
    }
    return result;
}
Outcome World::simulate(double angle,double speed,double side,double top,double seconds)const{
    World preview(config);
    preview.reset(balls);
    preview.strike(angle,speed,side,top);
    const int limit=static_cast<int>(std::clamp(seconds,0.0,120.0)/stepSize);
    for(int i=0;i<limit&&preview.moving();++i)preview.step();
    return {preview.events,preview.balls,preview.time,!preview.moving()};
}
std::vector<V2> World::idealGuide(V2 p,double angle,int count)const{
    std::vector<V2> points{p};V2 d{std::cos(angle),std::sin(angle)};
    double x=config.width/2-config.railRadius(),y=config.length/2-config.railRadius();
    for(int k=0;k<=count;k++){
        double tx=std::abs(d.x)>1e-10?((d.x>0?x:-x)-p.x)/d.x:1e9;
        double ty=std::abs(d.y)>1e-10?((d.y>0?y:-y)-p.y)/d.y:1e9;
        double dist=std::min(tx,ty);if(dist<1e-8||dist>100)break;
        // Stop at the first object ball, using an expanded sphere for the cue centre.
        double hit=dist;
        for(const auto&b:balls)if(!b.sunk&&b.id!=0){
            V2 rel=p-b.p;double a=rel.dot(d),c=rel.dot(rel)-4*config.radius*config.radius;
            double disc=a*a-c;if(disc>=0){double h=-a-std::sqrt(disc);if(h>1e-5&&h<hit)hit=h;}
        }
        V2 q=p+d*hit;points.push_back(q);if(hit<dist)break;
        // An ideal mirror is invalid at a pocket mouth; end the guide there.
        bool mouth=tx<ty?(std::abs(q.y)<.09||std::abs(q.y)>config.length/2-.11):std::abs(q.x)>config.width/2-.11;
        if(mouth)break;
        if(std::abs(tx-ty)<1e-8){d.x=-d.x;d.y=-d.y;}else if(tx<ty)d.x=-d.x;else d.y=-d.y;
        p=q+d*1e-7;
    }
    return points;
}
}
