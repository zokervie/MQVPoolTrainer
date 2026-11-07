#include "Physics.hpp"
#include "CueSlateContact.hpp"
#include "CushionContact3D.hpp"
// Research solver, SI; tabletop axes x,y, vertical axis z. Flat slate and
// spherical cushion-nose contact. Not a coupled/compliant cue-ball-slate model.
namespace banklab { namespace {
struct Vec {
    double x=0,y=0,z=0;
    Vec operator+(Vec b)const{return{x+b.x,y+b.y,z+b.z};}
    Vec operator-(Vec b)const{return{x-b.x,y-b.y,z-b.z};}
    Vec operator*(double a)const{return{x*a,y*a,z*a};}
    double dot(Vec b)const{return x*b.x+y*b.y+z*b.z;}
    double length()const{return std::sqrt(dot(*this));}
    Vec cross(Vec b)const{return{y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x};}
};
Vec velocity(const Ball&b){return{b.v.x,b.v.y,b.vertical};}
Vec omega(const Ball&b){return{b.w.x,b.w.y,b.spin};}
void setVelocity(Ball&b,Vec v){b.v={v.x,v.y};b.vertical=v.z;}
void setOmega(Ball&b,Vec w){b.w={w.x,w.y};b.spin=w.z;}
Vec cap(Vec v,double limit){double n=v.length();return n>limit&&n>0?v*(limit/n):v;}
void impulse(Ball&b,Vec arm,Vec j,double r){
    setVelocity(b,velocity(b)+j);
    setOmega(b,omega(b)+arm.cross(j)*(2.5/(r*r)));
}
void floorImpact(Ball&b,const Config&c,bool rebound){
    b.height=0;
    if(b.vertical>=0)return;
    const double r=c.radius,jn=-(1+(rebound?c.slateRestitution:0))*b.vertical;
    const Vec arm{0,0,-r};
    Vec slip=velocity(b)+omega(b).cross(arm);slip.z=0;
    Vec jt=cap(slip*(-1/3.5),c.slateFriction*jn);
    impulse(b,arm,Vec{jt.x,jt.y,jn},r);
    if(b.vertical<.035)b.vertical=0;
}
void orientation(Ball&b,double dt){
    const Vec w=omega(b);const double n=w.length();if(n<1e-12)return;
    const double h=n*dt/2,s=std::sin(h)/n;
    const Rotation d{w.x*s,w.y*s,w.z*s,std::cos(h)},q=b.rotation;
    Rotation z{d.w*q.x+d.x*q.w+d.y*q.z-d.z*q.y,
        d.w*q.y-d.x*q.z+d.y*q.w+d.z*q.x,
        d.w*q.z+d.x*q.y-d.y*q.x+d.z*q.w,
        d.w*q.w-d.x*q.x-d.y*q.y-d.z*q.z};
    const double norm=std::sqrt(z.x*z.x+z.y*z.y+z.z*z.z+z.w*z.w);
    b.rotation={z.x/norm,z.y/norm,z.z/norm,z.w/norm};
}
}
void World::strikeElevated(double angle,double speed,double side,double top){
    if(moving())return;
    auto it=std::find_if(balls.begin(),balls.end(),[](const Ball&b){return b.id==0&&!b.sunk;});
    if(it==balls.end())return;
    speed=std::clamp(speed*config.cueSpeedGain(),0.0,Config::maxBallSpeed);
    const double lim=config.tipMaxOffset(true),offset=std::hypot(side,top);if(offset>lim){side*=lim/offset;top*=lim/offset;}
    const double elevation=std::clamp(config.cueElevationDegrees,0.0,88.0)*pi/180; // 90° trên giao diện ≈ dựng đứng; 88° tránh hướng suy biến
    const double ca=std::cos(angle),sa=std::sin(angle),ce=std::cos(elevation),se=std::sin(elevation);
    const Vec direction{ca*ce,sa*ce,-se},lateral{-sa,ca,0},up{ca*se,sa*se,ce};
    const Vec arm=(direction*(-std::sqrt(1-side*side-top*top))+lateral*side+up*top)*config.radius;
    // 0.15: lực vuốt = tốc độ bi khi đánh tâm, cơ ngang — cùng thang với cú phẳng (trước đây bi chỉ đạt
    // 0,66× số đo vuốt nên cú nhảy hụt dù vuốt mạnh). Hiệu suất tương đối theo loại cơ [giả định]:
    // cơ nhảy (nhẹ, cứng, đầu phenolic) 1,00; cơ massé 0,93; cơ thường 0,89 (tỉ lệ giữ từ bản 0.11).
    const double relative=config.cueType==1?1.0:config.cueType==2?.82/.88:.78/.88;
    // TP A.30: đánh lệch tâm d → bi chậm hơn theo (1+m/M)/(1+m/M+2,5d²).
    const double k=1+config.mass/config.cueMass();
    const double launch=relative*speed*(k/(k+2.5*(side*side+top*top)));
    it->height=0;setVelocity(*it,direction*launch);
    setOmega(*it,arm.cross(direction*launch)*(2.5/(config.radius*config.radius)));
    // Coupled massé (cueType 0 with the cue raised): cue, ball and slate in one impact. Cue speed is mapped so
    // a centre hit with a level cue gives the same ball speed as the sequential model: u = v(1+m/M)/(1+e).
    if(config.masseCoupledContact&&config.cueType==0&&elevation>1e-6){
        const double e=std::clamp(config.masseCueRestitution,0.0,1.0),M=config.cueMass();
        const double cueSpeed=relative*speed*(1+config.mass/M)/(1+e);
        const auto coupled=cuecontact::solve({direction.x,direction.y,direction.z},{arm.x,arm.y,arm.z},cueSpeed,config.radius,config.mass,M,e,config.slateFriction);
        if(coupled.valid){setVelocity(*it,{coupled.velocity.x,coupled.velocity.y,coupled.velocity.z});setOmega(*it,{coupled.omega.x,coupled.omega.y,coupled.omega.z});}
    }
    // TP A.31: squirt cho thành phần ngang, cùng chiều quay ω_z (bi lệch ngược phía effect).
    if(config.squirtEnabled){const double a=config.squirtScale()*std::copysign(squirtAngle(side,config.mass,config.cueEndMass()),it->spin);
     const double vx=it->v.x,vy=it->v.y;it->v={vx*std::cos(a)-vy*std::sin(a),vx*std::sin(a)+vy*std::cos(a)};}
    // Sequential cue impulse then slate response: explicit approximation, not a fake arc.
    // 0.15 (yêu cầu 27/10): chỉ cơ Phá/Jump (cueType 1, 2) làm bi bật khỏi mặt bàn. Cơ Đánh/Massé (0)
    // nâng cơ thì mặt bàn hấp thụ thành phần thẳng đứng; ma sát mặt bàn vẫn tạo xoáy cong (massé).
    floorImpact(*it,config,config.cueType!=0);
    for(auto&b:balls)b.rails=0;
    events.clear();time=0;accumulator=0;
}
void World::stepElevated(double dt){
    if(!std::isfinite(dt)||dt<=0||dt>.01)return;
    // Bound translational displacement per substep. This is not a general 3D TOI solver.
    double fastest=0;for(const auto&b:balls)fastest=std::max(fastest,velocity(b).length());
    const int slices=std::max(2,static_cast<int>(std::ceil(fastest*dt/(config.radius*.12))));
    const double h=dt/slices,r=config.radius;
    for(int sub=0;sub<slices;sub++){
        for(auto&b:balls){
            if(b.sunk)continue;
            if(b.height>1e-9||b.vertical>1e-6){
                // Split the free flight exactly at a flat-slate landing.
                const double landing=(b.vertical+std::sqrt(b.vertical*b.vertical+2*9.81*b.height))/9.81;
                const double flight=std::min(h,std::max(0.0,landing));
                b.p+=b.v*flight;b.height+=b.vertical*flight-4.905*flight*flight;b.vertical-=9.81*flight;
                if(landing<=h){floorImpact(b,config,true);const double left=h-flight;
                    if(b.vertical>0){b.p+=b.v*left;b.height=b.vertical*left-4.905*left*left;b.vertical-=9.81*left;}
                    else cloth(b,left);
                }
            }else {b.height=0;b.vertical=0;cloth(b,h);}
            if(b.height<0)floorImpact(b,config,false);
            orientation(b,h);
        }
        time+=h;
        // 0.31: ball-ball contacts of this slice are collected first, then resolved EARLIEST FIRST (by time of
        // impact). Contacts that touch at the same instant (frozen rack, symmetric break) form one group solved
        // SIMULTANEOUSLY (projected Jacobi). Before, pairs were solved in array order: the same centred break
        // ended up to ~1.2 m different just by listing the balls in reverse, and mirror-asymmetric
        // (Tests/BreakSymmetryTests.cpp). A group of one contact is exactly the previous sequential code.
        struct Contact{size_t i,j;Vec normal;double closing,rewind;};
        std::vector<Contact> contacts;
        for(size_t i=0;i<balls.size();i++)for(size_t j=i+1;j<balls.size();j++){
            auto&a=balls[i];auto&b=balls[j];if(a.sunk||b.sunk)continue;
            Vec delta{b.p.x-a.p.x,b.p.y-a.p.y,b.height-a.height};
            const double length=delta.length();if(length>2*r||length<1e-10)continue;
            Vec normal=delta*(1/length);const Vec relative=velocity(b)-velocity(a);
            const double closing=relative.dot(normal),overlap=2*r-length;
            // Phát hiện sau khi đã chồng lấn: lùi cặp bi về đúng thời điểm chạm (|Δ − v_rel·τ| = 2R) để pháp tuyến
            // đúng (Tests/LiteratureTests.cpp). Trong τ (≤ 1 lát) bỏ qua ma sát nỉ.
            double rewind=0;
            if(closing<0){
                const double a2=relative.dot(relative),dr=delta.dot(relative),c2=delta.dot(delta)-4*r*r;
                const double disc=dr*dr-a2*c2;
                if(a2>1e-18&&disc>=0)rewind=std::clamp((dr+std::sqrt(disc))/a2,0.0,h);
            }
            if(rewind>0){
                const Vec touch=delta-relative*rewind;normal=touch*(1/std::max(1e-12,touch.length()));
            }else{
                a.p-=V2{normal.x,normal.y}*(overlap/2);b.p+=V2{normal.x,normal.y}*(overlap/2);
                a.height=std::max(0.0,a.height-normal.z*overlap/2);b.height=std::max(0.0,b.height+normal.z*overlap/2);
            }
            if(closing>=0)continue;
            contacts.push_back({i,j,normal,closing,rewind});
        }
        // earliest contact first (largest rewind); ties keep pair order but are solved together below
        std::stable_sort(contacts.begin(),contacts.end(),[](const Contact&x,const Contact&y){return x.rewind>y.rewind+1e-9;});
        for(size_t g=0;g<contacts.size();){
            size_t e=g+1;while(e<contacts.size()&&std::abs(contacts[e].rewind-contacts[g].rewind)<=1e-9)++e;
            std::vector<size_t> members;for(size_t k=g;k<e;++k){members.push_back(contacts[k].i);members.push_back(contacts[k].j);}
            std::sort(members.begin(),members.end());members.erase(std::unique(members.begin(),members.end()),members.end());
            std::vector<double> rewindOf(balls.size(),0.0);std::vector<Vec> before(balls.size());
            for(size_t k=g;k<e;++k){rewindOf[contacts[k].i]=std::max(rewindOf[contacts[k].i],contacts[k].rewind);rewindOf[contacts[k].j]=std::max(rewindOf[contacts[k].j],contacts[k].rewind);}
            for(size_t m:members)before[m]=velocity(balls[m]);
            // geometry at the touch instant: move back along the pre-impact velocity
            for(size_t m:members){const Vec v=before[m];balls[m].p-=V2{v.x,v.y}*rewindOf[m];balls[m].height-=v.z*rewindOf[m];}
            const size_t n=e-g;
            std::vector<double> lambda(n,0.0);
            if(n==1){
                const auto&c=contacts[g];lambda[0]=-(1+config.ballRestitution)*c.closing/2;
                impulse(balls[c.i],c.normal*r,c.normal*(-lambda[0]),r);impulse(balls[c.j],c.normal*(-r),c.normal*lambda[0],r);
            }else{
                // projected Jacobi on the normal impulses: every contact sees the same velocities each sweep, so the
                // answer does not depend on the order of the balls; relaxation 1/(max contacts per ball) converges.
                std::vector<int> degree(balls.size(),0);for(size_t k=g;k<e;++k){++degree[contacts[k].i];++degree[contacts[k].j];}
                int maxDegree=1;for(size_t m:members)maxDegree=std::max(maxDegree,degree[m]);
                const double relax=1.0/maxDegree;
                for(int sweep=0;sweep<400;++sweep){
                    std::vector<double> delta(n,0.0);double worst=0;
                    for(size_t k=0;k<n;++k){const auto&c=contacts[g+k];
                        const double now=(velocity(balls[c.j])-velocity(balls[c.i])).dot(c.normal);
                        const double target=-config.ballRestitution*c.closing;   // separating speed
                        const double next=std::max(0.0,lambda[k]+relax*(target-now)/2);
                        delta[k]=next-lambda[k];worst=std::max(worst,std::abs(delta[k]));}
                    for(size_t k=0;k<n;++k){if(delta[k]==0)continue;const auto&c=contacts[g+k];lambda[k]+=delta[k];
                        impulse(balls[c.i],c.normal*r,c.normal*(-delta[k]),r);impulse(balls[c.j],c.normal*(-r),c.normal*delta[k],r);}
                    if(worst<1e-10)break;
                }
            }
            // friction (throw, gear effect), capped by each contact's normal impulse — also simultaneous
            std::vector<Vec> friction(n);
            for(size_t k=0;k<n;++k){const auto&c=contacts[g+k];auto&a=balls[c.i];auto&b=balls[c.j];
                const Vec arm=c.normal*r,relative=velocity(b)-velocity(a),slip=relative-(omega(a)+omega(b)).cross(arm);
                const Vec tangent=slip-c.normal*slip.dot(c.normal);
                friction[k]=cap(tangent*(-1/7.0),config.ballFrictionAt(tangent.length())*lambda[k]);}
            for(size_t k=0;k<n;++k){const auto&c=contacts[g+k];
                impulse(balls[c.i],c.normal*r,friction[k]*(-1),r);impulse(balls[c.j],c.normal*(-r),friction[k],r);}
            // 0.32: a ball driven DOWN into the slate by another ball bounces with the slate restitution (0.5 [PP]) —
            // an airborne cue ball landing on top of an object ball makes it hop like a second jump shot (Alciatore HSV).
            for(size_t m:members){auto&b=balls[m];if(b.height<=0)floorImpact(b,config,true);
                // Đi tiếp phần thời gian đã lùi với vận tốc mới.
                const Vec v=velocity(b);b.p+=V2{v.x,v.y}*rewindOf[m];b.height=std::max(0.0,b.height+v.z*rewindOf[m]);}
            for(size_t k=g;k<e;++k){const auto&c=contacts[k];events.push_back({1,balls[c.i].id,balls[c.j].id,time,(balls[c.i].p+balls[c.j].p)*.5,std::abs(c.closing)});}
            g=e;
        }
        for(auto&b:balls){
            if(b.sunk)continue;
            for(const auto&s:segments){
                const V2 edge=s.b-s.a;const double len2=edge.dot(edge);if(len2<=0)continue;
                const V2 point=s.a+edge*std::clamp((b.p-s.a).dot(edge)/len2,0.0,1.0);
                Vec delta{b.p.x-point.x,b.p.y-point.y,b.height-(config.railNoseHeightMeters()-r)};
                const double distance=delta.length();if(distance>=r||distance<1e-10)continue;
                const Vec normal=delta*(1/distance),arm=normal*(-r),contact=velocity(b)+omega(b).cross(arm);
                const double vn=contact.dot(normal);if(vn>=0)continue;
                const double e=std::clamp(config.bounce(s.rail)-config.railSpeedSensitivity*std::abs(vn),.4,.98);
                const double jn=-(1+e)*vn;const Vec slip=contact-normal*vn;
                if(config.coupledCushions){
                    auto out=contact3d::solve({b.v.x,b.v.y,b.vertical},{b.w.x,b.w.y,b.spin},{normal.x,normal.y,normal.z},r,e,config.grip(s.rail),config.slateFriction,b.height<=1e-8&&b.vertical<=1e-6,config.railTangentialRestitution);
                    setVelocity(b,{out.velocity.x,out.velocity.y,out.velocity.z});setOmega(b,{out.omega.x,out.omega.y,out.omega.z});
                }else impulse(b,arm,normal*jn+cap(slip*(-1/3.5),config.grip(s.rail)*jn),r);
                b.p+=V2{normal.x,normal.y}*(r-distance+1e-9);b.height=std::max(0.0,b.height+normal.z*(r-distance));
                if(b.height<=0)floorImpact(b,config,false);
                b.rails++;events.push_back({0,b.id,s.rail,time,point,std::abs(vn)});
            }
            // Pockets still use the existing capture basins after landing, not while airborne.
            if(b.height<.002)pocket(b);
            if(std::abs(b.p.x)>config.width/2+.30||std::abs(b.p.y)>config.length/2+.30){
                const double impact=velocity(b).length();
                b.sunk=true;b.v={};b.w={};b.spin=0;b.vertical=0;
                events.push_back({2,b.id,-1,time,b.p,impact});
            }
        }
    }
}
}
