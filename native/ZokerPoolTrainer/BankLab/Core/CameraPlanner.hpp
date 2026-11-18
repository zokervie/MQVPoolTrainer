// 0.48 M1 "Máy quay": bộ lập kế hoạch máy quay cho xem lại (header-only C++17, chỉ STL — test Linux biên dịch được).
//
// Vào: bản ghi (vị trí bi theo thời gian + sự kiện như BLWorld), góc ngắm, kiểu máy, tỉ lệ khung, lead/tail.
// Ra : danh sách cảnh (thời điểm cắt, kiểu, bi chính), đường máy (mắt, điểm nhìn, FOV dọc) đã làm mượt HAI CHIỀU
//      trong từng cảnh (không lọc qua điểm cắt), đường cong tốc độ phát (rate) liên tục.
//
// Nguyên tắc DOP (docs/de-xuat/NHIEM-VU-0.48-MAY-QUAY.md mục 2): lập kế hoạch trên toàn bản ghi, máy đi trước bi,
// cắt tại/ trước khoảnh khắc chính (không cắt trong 0,3 s trước), cảnh >= 1,2 s THẬT, luật 180°, chậm dần vào ×0,35
// trong 0,25 s và nhanh dần ra trong 0,35 s (smoothstep theo thời gian thật), máy thấp chỉ cho khoảnh khắc anh hùng.
//
// Toạ độ BÀN: x ngang bàn (±0,635), y dọc bàn (±1,27), z hướng lên từ mặt nỉ; tâm bi z = R.
// SceneKit = (x, z, y) — chuyển ở cầu ObjC++ (BLCameraPlan.mm). Vector "lên" của máy = +z bàn (= +y scene);
// máy không bao giờ nhìn thẳng đứng (luôn lệch ngang >= 0,35 m) nên look(at:up:) không suy biến.
//
// Hình học che khuất (dùng cho kiểm "bi chính nhìn thấy"):
//  - Bi khác: cầu bán kính R (bi đã rơi bỏ qua).
//  - Băng: dải mũi băng cao 0,037 m từ đường mũi băng (|x| = 0,635 / |y| = 1,27) ra tới 0,66 / 1,30, gỗ thành bàn cao
//    0,045 m rộng 0,15 m phía sau (số theo đề 0.48). Dải dọc theo đúng các đoạn mũi băng của World::buildRails
//    (hở ở các lỗ). GIẢ ĐỊNH: mặt dốc của cao su và phần gỗ bo quanh lỗ không mô hình hoá.
//  - Chụp đèn: hộp khung đèn thật của TableScene.tableFixture() (khung x ±0,47+0,0225, z bàn ±1,03+0,0225, cao 2,45 m
//    so với mặt nỉ, dày 0,035 m) — ĐÃ ĐO từ mã, không giả định. Máy luôn thấp hơn 2,25 m nên đèn không chắn.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

namespace banklab::camera {

constexpr double kPi=3.14159265358979323846;
constexpr double kDeg=180.0/kPi;

struct V3{double x=0,y=0,z=0;};
inline V3 operator+(V3 a,V3 b){return{a.x+b.x,a.y+b.y,a.z+b.z};}
inline V3 operator-(V3 a,V3 b){return{a.x-b.x,a.y-b.y,a.z-b.z};}
inline V3 operator*(V3 a,double s){return{a.x*s,a.y*s,a.z*s};}
inline V3 operator*(double s,V3 a){return a*s;}
inline double dot(V3 a,V3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
inline V3 cross(V3 a,V3 b){return{a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
inline double len(V3 a){return std::sqrt(dot(a,a));}
inline V3 unit(V3 a){double n=len(a);return n>1e-12?a*(1/n):V3{};}
inline V3 flat(V3 a){return{a.x,a.y,0};}
inline V3 rotZ(V3 a,double r){double c=std::cos(r),s=std::sin(r);return{c*a.x-s*a.y,s*a.x+c*a.y,a.z};}
inline V3 lerp(V3 a,V3 b,double u){return a+(b-a)*u;}
inline double smoothstep(double u){u=std::clamp(u,0.0,1.0);return u*u*(3-2*u);}

/// Tiêu chí nghiệm thu M1 (test giữ cửa dùng đúng các số này; planner tự nhắm chặt hơn để có lề).
struct Limits{
    static constexpr double maxAngularSpeed=90;   // độ/s, trong cảnh, theo thời gian THẬT
    static constexpr double maxAngularAccel=600;  // độ/s²
    static constexpr double minScene=1.2;         // s thật
    static constexpr double preCut=.3;            // không cắt trong 0,3 s (thật) trước khoảnh khắc chính
    static constexpr double safeMargin=.08;       // bi chính cách mép khung >= 8 % → |NDC| <= 0,84
    static constexpr double minVisible=.95;
    static constexpr double maxRateSlope=4;       // |d rate / d t_thật|
    static constexpr double minRate=.35;
    static constexpr double teaserMax=6.5;        // s thật, startTime → endTime (thẻ cuối 1,5 s do Swift ghép)
};

namespace table {
constexpr double R=.028575,halfW=.635,halfL=1.27,noseH=.037,woodH=.045,woodX=.66,woodY=1.30,woodWidth=.15;
constexpr double lampX=.47+.0225,lampY=1.03+.0225,lampZ0=2.45-.0175,lampZ1=2.45+.0175;
inline V3 pocket(int i){
    static const double p[6][2]={{-.60,-1.235},{.60,-1.235},{-.66,0},{.66,0},{-.60,1.235},{.60,1.235}};
    i=std::clamp(i,0,5);return{p[i][0],p[i][1],0};
}
}

struct Box{V3 lo,hi;};
inline Box makeBox(V3 a,V3 b){return{{std::min(a.x,b.x),std::min(a.y,b.y),std::min(a.z,b.z)},{std::max(a.x,b.x),std::max(a.y,b.y),std::max(a.z,b.z)}};}
inline const std::vector<Box>& occluders(){
    static const std::vector<Box> boxes=[]{
        using namespace table;
        std::vector<Box> b;
        const double c=.1143/std::sqrt(2.0),g=.127/2,y0=halfL-c,x0=halfW-c;   // = World::buildRails
        for(int s:{-1,1}){
            for(auto span:{std::array<double,2>{{-y0,-g}},std::array<double,2>{{g,y0}}}){
                b.push_back(makeBox({s*halfW,span[0],0},{s*woodX,span[1],noseH}));
                b.push_back(makeBox({s*woodX,span[0],0},{s*(woodX+woodWidth),span[1],woodH}));
            }
            b.push_back(makeBox({-x0,s*halfL,0},{x0,s*woodY,noseH}));
            b.push_back(makeBox({-x0,s*woodY,0},{x0,s*(woodY+woodWidth),woodH}));
        }
        b.push_back(makeBox({-lampX,-lampY,lampZ0},{lampX,lampY,lampZ1}));
        return b;
    }();
    return boxes;
}
inline bool segmentHitsBox(V3 a,V3 b,const Box& bx){
    const double A[3]={a.x,a.y,a.z},D[3]={b.x-a.x,b.y-a.y,b.z-a.z},L[3]={bx.lo.x,bx.lo.y,bx.lo.z},H[3]={bx.hi.x,bx.hi.y,bx.hi.z};
    double t0=0,t1=1;
    for(int i=0;i<3;++i){
        if(std::abs(D[i])<1e-12){if(A[i]<L[i]||A[i]>H[i])return false;continue;}
        double u=(L[i]-A[i])/D[i],v=(H[i]-A[i])/D[i];if(u>v)std::swap(u,v);
        t0=std::max(t0,u);t1=std::min(t1,v);if(t0>t1)return false;
    }
    return true;
}
inline bool segmentHitsSphere(V3 a,V3 b,V3 c,double r){
    const V3 d=b-a;const double l2=dot(d,d);const double u=l2>0?std::clamp(dot(c-a,d)/l2,0.0,1.0):0.0;
    return len(a+d*u-c)<r;
}

struct RecEvent{int kind=0,a=0,b=0;double time=0,x=0,y=0,impact=0;};   // như BLWorld: 0 băng, 1 bi, 2 lỗ

/// Bản ghi: n khung, m bi; xs/ys/sunk hàng-trước [frame*m + bi], thứ tự bi = ids. Thời gian 0 = lúc đánh.
struct Recording{
    std::vector<double> times;int m=0;std::vector<int> ids;std::vector<double> xs,ys;std::vector<std::uint8_t> sunk;
    std::vector<RecEvent> events;
    std::vector<int> firstSunk;
    int n()const{return static_cast<int>(times.size());}
    void prepare(){
        firstSunk.assign(static_cast<std::size_t>(std::max(m,0)),n());
        for(int j=0;j<m;++j)for(int k=0;k<n();++k)if(sunk[static_cast<std::size_t>(k*m+j)]){firstSunk[static_cast<std::size_t>(j)]=k;break;}
    }
    int col(int id)const{for(int j=0;j<m;++j)if(ids[static_cast<std::size_t>(j)]==id)return j;return -1;}
    V3 at(int k,int j)const{const auto i=static_cast<std::size_t>(k*m+j);return{xs[i],ys[i],table::R};}
    int frameBelow(double t)const{
        if(n()==0)return 0;
        const int k=static_cast<int>(std::upper_bound(times.begin(),times.end(),t)-times.begin())-1;
        return std::clamp(k,0,n()-1);
    }
    bool sunkAt(int j,double t)const{
        if(j<0||j>=m||n()==0)return true;
        const int f=firstSunk[static_cast<std::size_t>(j)];
        return f<n()&&t>=times[static_cast<std::size_t>(f)];
    }
    /// Vị trí (nội suy tuyến tính). Bi đã rơi: giữ vị trí khung cuối còn trên bàn.
    V3 pos(int j,double t)const{
        if(j<0||j>=m||n()==0)return{0,0,table::R};
        const int last=std::max(0,firstSunk[static_cast<std::size_t>(j)]-1);
        const int k=frameBelow(t);
        if(k>=last)return at(last,j);
        if(t<=times[0])return at(0,j);
        const double dt=std::max(1e-9,times[static_cast<std::size_t>(k+1)]-times[static_cast<std::size_t>(k)]);
        return lerp(at(k,j),at(k+1,j),std::clamp((t-times[static_cast<std::size_t>(k)])/dt,0.0,1.0));
    }
    V3 vel(int j,double t,double h=.04)const{return(pos(j,t+h)-pos(j,t-h))*(1/(2*h));}
};

/// Bi chính nhìn thấy: tia mắt → TÂM bi không cắt bi khác (còn trên bàn), băng/gỗ, chụp đèn.
inline bool ballVisible(const Recording& r,int j,double t,V3 eye){
    const V3 c=r.pos(j,t);
    for(int o=0;o<r.m;++o){if(o==j||r.sunkAt(o,t))continue;if(segmentHitsSphere(eye,c,r.pos(o,t),table::R*.98))return false;}
    for(const auto& b:occluders())if(segmentHitsBox(eye,c,b))return false;
    return true;
}

struct Pose{V3 eye,target;double fov=40;};   // fov: dọc, độ
struct Basis{V3 f,r,u;};
inline Basis basis(V3 eye,V3 target){
    const V3 f=unit(target-eye);V3 r=cross(f,{0,0,1});if(len(r)<1e-6)r={1,0,0};r=unit(r);return{f,r,cross(r,f)};
}
/// Chiếu điểm q vào khung: NDC [-1,1] (x ngang, y dọc). false nếu sau máy.
inline bool project(const Pose& p,double aspect,V3 q,double& nx,double& ny){
    const Basis b=basis(p.eye,p.target);const V3 d=q-p.eye;const double zc=dot(d,b.f);
    if(zc<1e-3)return false;
    const double tv=std::tan(p.fov/2/kDeg);ny=dot(d,b.u)/(zc*tv);nx=dot(d,b.r)/(zc*tv*aspect);return true;
}
/// tan(FOV/2) tối thiểu để q nằm trong |NDC| <= lim.
inline double neededTan(V3 eye,V3 target,V3 q,double aspect,double lim){
    const Basis b=basis(eye,target);const V3 d=q-eye;const double zc=dot(d,b.f);
    if(zc<1e-3)return std::numeric_limits<double>::infinity();
    return std::max(std::abs(dot(d,b.u)),std::abs(dot(d,b.r))/aspect)/(zc*lim);
}

/// Luật 180° — ĐỊNH NGHĨA: tại mỗi điểm cắt c, "đường hành động" là đường thẳng (trên mặt bàn) qua bi đang chạy nhanh
/// nhất lúc c, theo hướng vận tốc của nó; nếu không bi nào chạy (> 5 cm/s) thì là đường ngắm qua bi cái ban đầu.
/// Mắt cuối cảnh trước và mắt đầu cảnh sau phải cùng phía đường này (khoảng cách có dấu cùng dấu), trừ khi một trong
/// hai nằm trên trục (|khoảng cách| < 5 cm — máy trên trục được phép, như quy ước dựng phim).
struct Axis{V3 p,d;};
inline Axis actionAxis(const Recording& r,double t,double aimAngle){
    int best=-1;double speed=.05;
    for(int j=0;j<r.m;++j){if(r.sunkAt(j,t))continue;const double s=len(flat(r.vel(j,t)));if(s>speed){speed=s;best=j;}}
    if(best<0){const int c=std::max(0,r.col(0));return{flat(r.pos(c,0)),{std::cos(aimAngle),std::sin(aimAngle),0}};}
    return{flat(r.pos(best,t)),unit(flat(r.vel(best,t)))};
}
inline double axisSide(const Axis& a,V3 eye){const V3 e=flat(eye)-a.p;return a.d.x*e.y-a.d.y*e.x;}
constexpr double kAxisNeutral=.05;
inline bool sameSide180(double a,double b){return a*b>=0||std::min(std::abs(a),std::abs(b))<kAxisNeutral;}

/// Làm mượt hai chiều (không trễ pha): 4 lượt lọc hộp ≈ Gauss σ (mẫu). odd = phản xạ lẻ ở biên (giữ xu hướng tuyến
/// tính, không gãy vận tốc ở đầu/cuối cảnh); even = phản xạ chẵn (dùng cho FOV: không tụt dưới giá trị cần).
template<class T> std::vector<T> smoothSeq(const std::vector<T>& x,double sigma,bool odd=true,int* support=nullptr){
    const int N=static_cast<int>(x.size());
    if(N<3||sigma<.5){if(support)*support=0;return x;}
    const int w=std::max(3,static_cast<int>(std::lround(std::sqrt(3*sigma*sigma+1))));
    const int h=std::max(1,w/2),pad=4*h+2;
    if(support)*support=4*h;
    std::vector<T> p(static_cast<std::size_t>(N+2*pad));
    for(int i=0;i<N+2*pad;++i){
        const int k=i-pad;T v;
        if(k<0){const int kk=std::min(-k,N-1);v=odd?x[0]*2.0-x[static_cast<std::size_t>(kk)]:x[static_cast<std::size_t>(kk)];}
        else if(k>=N){const int kk=std::min(k-(N-1),N-1);v=odd?x[static_cast<std::size_t>(N-1)]*2.0-x[static_cast<std::size_t>(N-1-kk)]:x[static_cast<std::size_t>(N-1-kk)];}
        else v=x[static_cast<std::size_t>(k)];
        p[static_cast<std::size_t>(i)]=v;
    }
    std::vector<T> q=p,pre(p.size()+1);
    for(int pass=0;pass<4;++pass){
        pre[0]=T{};for(std::size_t i=0;i<p.size();++i)pre[i+1]=pre[i]+p[i];
        for(int i=h;i<static_cast<int>(p.size())-h;++i)q[static_cast<std::size_t>(i)]=(pre[static_cast<std::size_t>(i+h+1)]-pre[static_cast<std::size_t>(i-h)])*(1.0/(2*h+1));
        p=q;
    }
    return std::vector<T>(p.begin()+pad,p.begin()+pad+N);
}
/// Catmull-Rom (C1) với điểm ma ngoại suy tuyến tính ở hai đầu (không gãy vận tốc ở biên cảnh).
template<class T> T catmull(const std::vector<T>& v,double k){
    const int N=static_cast<int>(v.size());
    if(N==1)return v[0];
    k=std::clamp(k,0.0,static_cast<double>(N-1));
    const int i=std::min(static_cast<int>(k),N-2);const double u=k-i;
    auto g=[&](int j)->T{
        if(j<0)return v[0]*2.0-v[1];
        if(j>=N)return v[static_cast<std::size_t>(N-1)]*2.0-v[static_cast<std::size_t>(N-2)];
        return v[static_cast<std::size_t>(j)];
    };
    const T p0=g(i-1),p1=g(i),p2=g(i+1),p3=g(i+2);
    return (p1*2.0+(p2-p0)*u+(p0*2.0-p1*5.0+p2*4.0-p3)*(u*u)+(p1*3.0-p0-p2*3.0+p3)*(u*u*u))*0.5;
}

/// Một cửa sổ đổi tốc độ: rate 1 → r (chậm dần/nhanh dần theo smoothstep của THỜI GIAN THẬT, dài inW giây),
/// giữ r trong holdRec giây bản ghi, rồi r → 1 trong outW giây thật. |d rate/d t_thật| <= 1,5·|r−1|/T.
struct RateWindow{
    double tIn=0,r=1,inW=.26,holdRec=0,outW=.38;
    double inRec()const{return inW*(1+r)/2;}
    double outRec()const{return outW*(1+r)/2;}
    double end()const{return tIn+inRec()+holdRec+outRec();}
    static double solve(double T,double a,double b,double off){   // T·(a·u + b·(u³ − u⁴/2)) = off
        double lo=0,hi=1;
        for(int i=0;i<48;++i){const double u=(lo+hi)/2,f=T*(a*u+b*(u*u*u-u*u*u*u/2));(f<off?lo:hi)=u;}
        return (lo+hi)/2;
    }
    bool inside(double t)const{return t>tIn&&t<end();}
    double rate(double t)const{
        const double t1=tIn+inRec(),t2=t1+holdRec,t3=t2+outRec();
        if(t<=tIn||t>=t3)return 1;
        if(t<t1)return 1+(r-1)*smoothstep(solve(inW,1,r-1,t-tIn));
        if(t<=t2)return r;
        return r+(1-r)*smoothstep(solve(outW,r,1-r,t-t2));
    }
};

enum class Style:int{Director=0,Learn=1,Shooter=2,Wide34=3,Overhead=4,FollowCue=5,RailSide=6,PocketMeet=7,Teaser=8};
enum class SceneKind:int{Open=0,Stroke=1,Impact=2,Travel=3,Pot=4,Settle=5,BreakWide=6,Wrap=7,Manual=8};

class Planner{
public:
    static constexpr double recommendedLead=3.0,recommendedTail=1.5;   // đủ cho 6 cảnh Đạo diễn (Mở 1,25 s + Ra cơ 1,25 s + cắt sớm)
    struct Scene{
        SceneKind kind=SceneKind::Manual;double t0=0,t1=0,w0=0,w1=0,step=1.0/120;
        int subject=-1,subject2=-1;double switchTime=0;     // cột bi chính (đổi sang subject2 tại switchTime)
        std::vector<V3> eye,target;std::vector<double> fov;double visible=1,peakW=0,peakA=0;
    };
    // Kết quả phân tích bản ghi (dùng cho test/ghi chép).
    double contactTime=std::numeric_limits<double>::quiet_NaN(),potTime=std::numeric_limits<double>::quiet_NaN();
    int cueCol=0,objectCol=-1,potCol=-1,potPocket=-1;bool isBreak=false;
    // Số đo.
    double bestStill=0,wallDuration=0,peakAngular=0,p95Angular=0,minVisible=1;

    Planner(Recording r,double aimAngle,Style s,double aspect,double lead,double tail)
        :rec(std::move(r)),aim(aimAngle),style(s),aspect(aspect>0.05?aspect:16.0/9),lead(std::max(0.0,lead)),tail(std::max(0.0,tail)){
        rec.prepare();analyse();
        if(style==Style::Director||style==Style::Teaser)buildDirector(style==Style::Teaser);else buildManual();
        finish();
    }
    double startTime()const{return tA;}
    double endTime()const{return tB;}
    double rate(double t)const{for(const auto& w:windows)if(w.inside(t))return w.rate(t);return 1;}
    double wall(double t)const{
        if(wallTbl.empty())return t;
        const double k=(t-tLo)/kTblStep;
        if(k<=0)return wallTbl.front()+(t-tLo);
        const auto last=static_cast<double>(wallTbl.size()-1);
        if(k>=last)return wallTbl.back()+(t-(tLo+last*kTblStep));
        const auto i=static_cast<std::size_t>(k);const double f=k-static_cast<double>(i);
        return wallTbl[i]*(1-f)+wallTbl[i+1]*f;
    }
    double recordAt(double w)const{
        if(wallTbl.empty())return w;
        if(w<=wallTbl.front())return tLo+(w-wallTbl.front());
        if(w>=wallTbl.back())return tLo+static_cast<double>(wallTbl.size()-1)*kTblStep+(w-wallTbl.back());
        const auto i=static_cast<std::size_t>(std::upper_bound(wallTbl.begin(),wallTbl.end(),w)-wallTbl.begin())-1;
        const double f=(w-wallTbl[i])/std::max(1e-12,wallTbl[i+1]-wallTbl[i]);
        return tLo+(static_cast<double>(i)+f)*kTblStep;
    }
    int sceneIndex(double t)const{
        int i=0;for(int k=1;k<static_cast<int>(scenes.size());++k)if(t>=scenes[static_cast<std::size_t>(k)].t0)i=k;return i;
    }
    const std::vector<Scene>& sceneList()const{return scenes;}
    SceneKind sceneKind(double t)const{return scenes.empty()?SceneKind::Manual:scenes[static_cast<std::size_t>(sceneIndex(t))].kind;}
    int subjectColumn(double t)const{
        if(scenes.empty())return -1;const auto& s=scenes[static_cast<std::size_t>(sceneIndex(t))];
        return(s.subject2>=0&&t>=s.switchTime)?s.subject2:s.subject;
    }
    int subjectBall(double t)const{const int c=subjectColumn(t);return c<0?-1:rec.ids[static_cast<std::size_t>(c)];}
    Pose pose(double t)const{
        if(scenes.empty())return{};
        t=std::clamp(t,tA,tB);
        const auto& s=scenes[static_cast<std::size_t>(sceneIndex(t))];
        const double k=(wall(t)-s.w0)/s.step;
        return{catmull(s.eye,k),catmull(s.target,k),catmull(s.fov,k)};
    }
    double trailReveal(double t)const{
        if(style==Style::Learn){const double e=rec.n()?rec.times.back():0;return e<=0?1:std::clamp(t/e,0.0,1.0);}
        if(style==Style::Director||style==Style::Teaser){
            for(const auto& s:scenes)if(s.kind==SceneKind::Wrap)return t>=s.t0?1:0;
        }
        return 0;
    }
    const Recording& recording()const{return rec;}
    double aimAngle()const{return aim;}
    double frameAspect()const{return aspect;}

private:
    static constexpr double kTblStep=.0005,kHz=120,kNdc=.80;   // planner nhắm |NDC| <= 0,80 (tiêu chí 0,84)
    static constexpr double kPlanW=80,kPlanA=450,kPlanVis=.97,kFovMax=80,kMinScene=1.25,kPreCut=.32;
    Recording rec;double aim;Style style;double aspect,lead,tail;
    std::vector<RateWindow> windows;std::vector<double> wallTbl;double tLo=0,tA=0,tB=0;
    std::vector<Scene> scenes;
    V3 aimDir{},perp{},cue0{};int sidePref=1;double tEnd=0,tStopOB=0,tFew=0,slowEnd=0;

    struct Want{SceneKind k;double w;int subj;int prio;};
    struct Cand{int s=1;double a=0,h=0,d=0;int v=0;};
    struct Extra{double baseFov=40,softCap=65;std::vector<V3> soft;int softBall=-1;};

    V3 P(int j,double t)const{return rec.pos(j,t);}
    static V3 capped(V3 d,double cap=.15){const double l=len(d);return l>cap?d*(cap/l):d;}
    /// "Máy đi trước bi": điểm nhìn lệch về phía bi sắp đi, nhưng không quá 15 cm (bi phá 8 m/s không kéo khung đi mất).
    V3 lookP(int j,double t,double dt,double frac)const{const V3 p=P(j,t);return p+capped((P(j,t+dt)-p)*frac);}
    bool hasContact()const{return std::isfinite(contactTime);}
    bool hasPot()const{return potCol>=0;}

    void analyse(){
        cueCol=std::max(0,rec.col(0));
        aimDir={std::cos(aim),std::sin(aim),0};perp={-aimDir.y,aimDir.x,0};
        tEnd=rec.n()?rec.times.back():0;cue0=P(cueCol,0);
        int obId=-1;
        for(const auto& e:rec.events)if(e.kind==1&&(e.a==0||e.b==0)){contactTime=e.time;obId=e.a==0?e.b:e.a;break;}
        objectCol=obId>=0?rec.col(obId):-1;
        const RecEvent* pot=nullptr;
        for(const auto& e:rec.events)if(e.kind==2&&e.a!=0&&e.b>=0&&e.a==obId){pot=&e;break;}
        if(!pot)for(const auto& e:rec.events)if(e.kind==2&&e.a!=0&&e.b>=0){pot=&e;break;}
        if(pot&&hasContact()){potCol=rec.col(pot->a);potPocket=pot->b;potTime=pot->time;}
        int moved=0;
        for(int j=0;j<rec.m;++j){double mx=0;for(int k=0;k<rec.n();++k)mx=std::max(mx,len(rec.at(k,j)-rec.at(0,j)));if(mx>.02)++moved;}
        isBreak=hasContact()&&moved>=5;
        const int follow=objectCol>=0?objectCol:cueCol;
        tStopOB=0;
        for(int k=1;k<rec.n();++k){
            const double dt=std::max(1e-6,rec.times[static_cast<std::size_t>(k)]-rec.times[static_cast<std::size_t>(k-1)]);
            if(!rec.sunkAt(follow,rec.times[static_cast<std::size_t>(k)])&&len(rec.at(k,follow)-rec.at(k-1,follow))/dt>.01)tStopOB=rec.times[static_cast<std::size_t>(k)];
        }
        if(rec.sunkAt(follow,tEnd))tStopOB=rec.times[static_cast<std::size_t>(std::min(rec.firstSunk[static_cast<std::size_t>(follow)],rec.n()-1))];
        tFew=tEnd;
        if(isBreak)for(int k=1;k<rec.n();++k){
            const double t=rec.times[static_cast<std::size_t>(k)];if(t<contactTime+.4)continue;
            const double dt=std::max(1e-6,t-rec.times[static_cast<std::size_t>(k-1)]);int fast=0;
            for(int j=0;j<rec.m;++j)if(!rec.sunkAt(j,t)&&len(rec.at(k,j)-rec.at(k-1,j))/dt>.25)++fast;
            if(fast<=2){tFew=t;break;}
        }
        const V3 c=flat(V3{0,0,0}-cue0);const double side=aimDir.x*c.y-aimDir.y*c.x;
        sidePref=side<-.05?-1:1;
        if(hasPot())bestStill=potTime-.03;else if(hasContact())bestStill=contactTime+.02;else bestStill=0;
    }

    void buildWall(double lo,double hi){
        tLo=lo;const auto n=static_cast<std::size_t>(std::ceil((hi-lo)/kTblStep))+2;
        wallTbl.assign(n,0);
        for(std::size_t i=1;i<n;++i){
            const double t0=lo+static_cast<double>(i-1)*kTblStep,t1=t0+kTblStep;
            wallTbl[i]=wallTbl[i-1]+kTblStep*.5*(1/rate(t0)+1/rate(t1));
        }
    }

    // ---------- Lịch cảnh (thời gian thật w) ----------
    void normalize(std::vector<Want>& L,double wS,double wE,const std::vector<double>& keys)const{
        for(int iter=0;iter<80&&!L.empty();++iter){
            L.front().w=wS;bool changed=false;
            for(std::size_t i=1;i<L.size()&&!changed;++i){       // không cắt trong 0,3 s trước khoảnh khắc chính
                for(double K:keys)if(L[i].w>K-kPreCut&&L[i].w<K-1e-6){L[i].w=K-kPreCut;changed=true;break;}
            }
            for(std::size_t i=1;i<L.size()&&!changed;++i)if(L[i].w<=L[i-1].w){L.erase(L.begin()+static_cast<long>(L[i].prio>L[i-1].prio?i-1:i));changed=true;}
            if(changed)continue;
            for(std::size_t i=0;i<L.size()&&!changed;++i){
                const double end=i+1<L.size()?L[i+1].w:wE;
                if(end-L[i].w>=kMinScene)continue;
                if(i+1==L.size()&&i>0){                       // cảnh cuối ngắn: kéo điểm cắt sớm hơn nếu được
                    const double w=wE-kMinScene;bool ok=w-L[i-1].w>=kMinScene;
                    for(double K:keys)if(w>K-kPreCut&&w<K-1e-6)ok=false;
                    if(ok){L[i].w=w;changed=true;break;}
                }
                if(i+1<L.size()){                               // dời điểm cắt sau muộn hơn nếu cảnh sau vẫn đủ dài
                    const double w=L[i].w+kMinScene,nextEnd=i+2<L.size()?L[i+2].w:wE;bool ok=nextEnd-w>=kMinScene;
                    for(double K:keys)if(w>K-kPreCut&&w<K-1e-6)ok=false;
                    if(ok){L[i+1].w=w;changed=true;break;}
                }
                std::size_t other=i+1<L.size()?i+1:i-1;
                if(L.size()==1){changed=false;break;}
                std::size_t drop=L[i].prio>L[other].prio?other:i;
                if(drop==0&&L.size()>1){L.erase(L.begin());}
                else L.erase(L.begin()+static_cast<long>(drop));
                changed=true;
            }
            if(!changed)break;
        }
        if(!L.empty())L.front().w=wS;
    }
    // Lập lịch ngược từ khoảnh khắc chính: Lọt lỗ ← Bi chạy ← Va chạm ← Ra cơ ← Mở (mỗi cảnh >= 1,25 s thật).
    std::vector<Want> schedule(bool teaser,double& wStart,double& wEnd,bool& fits)const{
        const double W0=wall(0),wS=wall(-lead),wE=wall(tEnd+tail);
        const int wrapSubj=rec.sunkAt(cueCol,tEnd+1e9)?(objectCol>=0&&!rec.sunkAt(objectCol,tEnd+1e9)?objectCol:-1):cueCol;
        std::vector<Want> L;std::vector<double> keys{W0};
        const double wC=hasContact()?wall(contactTime):W0+.6;
        if(hasContact())keys.push_back(wC);
        if(hasPot())keys.push_back(wall(potTime));
        auto avoid=[&](double w){for(double K:keys)if(w>K-kPreCut&&w<K-1e-6)w=K-kPreCut;return w;};
        const double mw=teaser?kMinScene:1.3;
        double cImp=avoid(wC-.5);
        std::vector<Want> mid;double cWrap;
        if(isBreak){
            mid.push_back({SceneKind::BreakWide,cImp,cueCol,4});
            cWrap=std::max(cImp+mw,wall(tFew));
        }else if(hasContact()){
            double cTravel=std::max(cImp+mw,wall(slowEnd)+.05);
            if(hasPot()){
                const double wP=wall(potTime);
                double cPot=wP-(teaser?.75:.8);
                if(cPot-cTravel<mw){                     // cú ngắn: dời Lọt lỗ muộn (>= 0,4 s trước), Bi chạy & Va chạm sớm
                    cPot=std::max(cPot,std::min(wP-.4,cTravel+mw));
                    cTravel=std::max(std::min(cTravel,cPot-mw),wC+.1);
                    cImp=avoid(std::min(cImp,cTravel-mw));
                }
                mid.push_back({SceneKind::Impact,cImp,objectCol,4});
                mid.push_back({SceneKind::Travel,cTravel,potCol,1});
                mid.push_back({SceneKind::Pot,cPot,potCol,3});
                cWrap=std::max(cPot+mw,wP+(teaser?.45:1.0));
            }else{
                mid.push_back({SceneKind::Impact,cImp,objectCol,4});
                mid.push_back({SceneKind::Travel,cTravel,objectCol,1});
                const double cSettle=std::max(cTravel+mw,wall(tStopOB)-1.6);
                mid.push_back({SceneKind::Settle,cSettle,objectCol,2});
                cWrap=std::max(cSettle+mw,wall(tStopOB)+.3);
            }
        }else{
            const double cSettle=std::max(W0+.7,wall(tStopOB)-1.6);
            mid.push_back({SceneKind::Settle,cSettle,cueCol,2});cImp=cSettle;
            cWrap=std::max(cSettle+mw,wall(tStopOB)+.3);
        }
        const double cStroke=std::min(cImp-1.3,W0-.6);
        wStart=wS;
        if(teaser)wStart=std::max(wS,std::min(cImp-kMinScene,W0-.4));
        else L.push_back({SceneKind::Open,wS,cueCol,1});
        L.push_back({SceneKind::Stroke,teaser?wStart:cStroke,cueCol,2});
        L.insert(L.end(),mid.begin(),mid.end());
        fits=true;
        if(teaser){
            fits=cWrap+1.3<=wStart+Limits::teaserMax-.1;
            wEnd=std::min(cWrap+1.3,wStart+Limits::teaserMax-.1);
            wEnd=std::min(wEnd,wall(tLo+static_cast<double>(wallTbl.size()-2)*kTblStep));
            cWrap=wEnd-1.3;
        }else{wEnd=wE;cWrap=std::min(cWrap,wE-1.3);}
        L.push_back({SceneKind::Wrap,cWrap,wrapSubj,5});
        std::stable_sort(L.begin()+1,L.end(),[](const Want& x,const Want& y){return x.w<y.w;});
        normalize(L,wStart,wEnd,keys);
        return L;
    }
    void buildDirector(bool teaser){
        const bool contact=hasContact();
        // Đạo diễn, cú có lọt: nếu bi lăn tới lỗ quá nhanh để đủ 6 cảnh >= 1,2 s, giữ chậm ×0,35 lâu hơn (tới qua lúc
        // lọt) — "khoảnh khắc anh hùng". Thử dần, lấy độ giữ ngắn nhất cho đủ 6 cảnh.
        std::vector<double> holds{isBreak?.22:.12};
        if(!teaser&&contact&&hasPot()&&!isBreak)for(double h=.3;h<potTime-contactTime+.45;h+=.15)holds.push_back(h);
        double wS=0,wE=0;std::vector<Want> L;
        const double hi=tEnd+(teaser?std::max(tail,3.0):tail);
        const double ks[]={1.0,1.5,2.0,2.5,3.0};
        for(double hold:holds){
            for(double k:ks){
                windows.clear();
                if(contact){
                    RateWindow s;s.r=.35;s.inW=.26;s.outW=.38;s.holdRec=hold;s.tIn=contactTime-s.inRec();
                    windows.push_back(s);slowEnd=s.end();
                }
                if(teaser&&k>1&&contact){
                    const double a=slowEnd+.05,b=(hasPot()?potTime-1.0:(isBreak?tFew:tStopOB)-.3);
                    RateWindow f;f.r=k;f.inW=f.outW=(k-1)*1.5/3.5+.02;f.tIn=a;f.holdRec=(b-a)-f.inRec()-f.outRec();
                    if(f.holdRec>=0)windows.push_back(f);
                }
                buildWall(-lead,hi);
                bool fits=true;L=schedule(teaser,wS,wE,fits);
                if(!teaser||fits)break;
            }
            if(teaser||L.size()>=6)break;
        }
        tA=recordAt(wS);tB=recordAt(wE);if(!teaser){tA=-lead;tB=tEnd+tail;}
        for(std::size_t i=0;i<L.size();++i){
            Scene s;s.kind=L[i].k;s.subject=L[i].subj;
            s.w0=i==0?wall(tA):L[i].w;s.w1=i+1<L.size()?L[i+1].w:wall(tB);
            s.t0=i==0?tA:recordAt(s.w0);s.t1=i+1<L.size()?recordAt(s.w1):tB;
            scenes.push_back(s);
        }
        planScenes();
    }
    void buildManual(){
        windows.clear();buildWall(-lead,tEnd+tail);tA=-lead;tB=tEnd+tail;
        Scene s;s.kind=SceneKind::Manual;s.t0=tA;s.t1=tB;s.w0=wall(tA);s.w1=wall(tB);s.subject=cueCol;
        if(style==Style::RailSide&&objectCol>=0){s.subject2=objectCol;s.switchTime=contactTime;}
        if(style==Style::PocketMeet)s.subject=hasPot()?potCol:(objectCol>=0?objectCol:cueCol);
        scenes.push_back(s);
        planScenes();
    }

    // ---------- Đường máy từng cảnh ----------
    V3 clampRoom(V3 e)const{return{std::clamp(e.x,-3.4,3.4),std::clamp(e.y,-4.0,4.0),std::clamp(e.z,.12,2.25)};}
    void bboxPaths(V3& lo,V3& hi)const{
        lo={1e9,1e9,0};hi={-1e9,-1e9,0};
        for(int j=0;j<rec.m;++j){
            double mx=0;for(int k=0;k<rec.n();++k)mx=std::max(mx,len(rec.at(k,j)-rec.at(0,j)));
            if(mx<.02&&j!=cueCol)continue;
            for(int k=0;k<rec.n();k+=4){if(rec.sunkAt(j,rec.times[static_cast<std::size_t>(k)]))break;const V3 p=rec.at(k,j);
                lo={std::min(lo.x,p.x),std::min(lo.y,p.y),0};hi={std::max(hi.x,p.x),std::max(hi.y,p.y),0};}
        }
        if(lo.x>hi.x){lo={-.3,-.3,0};hi={.3,.3,0};}
    }
    static std::vector<V3> corners(V3 lo,V3 hi,double z=table::R){return{{lo.x,lo.y,z},{hi.x,lo.y,z},{lo.x,hi.y,z},{hi.x,hi.y,z}};}
    std::vector<Cand> candidates(SceneKind k)const{
        std::vector<Cand> c;
        auto grid=[&](std::initializer_list<double> as,std::initializer_list<double> hs,std::initializer_list<double> ds,int v=0){
            for(int s:{sidePref,-sidePref})for(double h:hs)for(double d:ds)for(double a:as)c.push_back({s,a,h,d,v});
        };
        switch(style==Style::Director||style==Style::Teaser?k:SceneKind::Manual){
        case SceneKind::Open:grid({.35,.55,.2},{1.3,1.6},{2.0,2.4});break;
        case SceneKind::Stroke:grid({.15,.25},{.25,.35,.5},{.95,.75});break;
        case SceneKind::Impact:grid({1.2,.9,1.5,.65},{.4,.6},{.9,1.2});break;
        case SceneKind::Travel:grid({0},{.45,.6,.8},{.9,1.2,.7});break;
        case SceneKind::Pot:grid({.70,.61,.785},{.2,.28,.38,.5},{.6,.8,1.0});break;
        case SceneKind::Settle:grid({1.0,.6,1.4,2.0},{.5,.7},{.9,1.2});break;
        case SceneKind::Wrap:for(int v:{0,4,2,6,1,3,5,7})for(double h:{2.1,1.9})for(double d:{1.5,1.2})c.push_back({1,0,h,d,v});break;
        case SceneKind::BreakWide:
            if(aspect>=1){grid({0},{1.6,1.9},{0},1);grid({0},{1.6,1.9},{0},0);}else{grid({0},{1.6,1.9},{0},0);grid({0},{1.6,1.9},{0},1);}
            break;
        case SceneKind::Manual:
            switch(style){
            case Style::Learn:grid({.5,.3},{1.6,1.9},{1.2,1.6});break;
            case Style::Overhead:grid({0},{2.2,2.0},{.4});break;
            case Style::Wide34:grid({.35,.55},{1.3,1.6},{2.0,2.4});break;
            case Style::Shooter:c.push_back({1,0,.35,1.1,0});c.push_back({1,0,.5,1.1,0});break;
            case Style::FollowCue:c.push_back({1,0,.35,1.0,0});c.push_back({1,0,.45,1.0,0});c.push_back({1,0,.6,.9,0});c.push_back({1,0,.8,.9,0});break;
            case Style::RailSide:grid({0},{.3,.4,.55,.75},{1.05,1.3});grid({0},{.4,.6},{1.7,2.2});break;
            case Style::PocketMeet:
                if(hasPot())grid({.70,.61,.785},{.25,.35,.5},{.6,.8,1.0});else grid({1.0,.6,1.4,2.0},{.5,.7},{.9,1.2});break;
            default:c.push_back({1,0,1,1,0});
            }
            break;
        }
        return c;
    }
    void raw(const Scene& sc,const Cand& c,const std::vector<double>& ts,const std::vector<double>& ws,std::vector<V3>& E,std::vector<V3>& T,Extra& x)const{
        const std::size_t N=ts.size();E.resize(N);T.resize(N);
        const double s=c.s;
        const SceneKind k=(style==Style::Director||style==Style::Teaser)?sc.kind:SceneKind::Manual;
        const int j=sc.subject>=0?sc.subject:cueCol;
        auto prog=[&](std::size_t i){return sc.w1>sc.w0?(ws[i]-sc.w0)/(sc.w1-sc.w0):0.0;};
        const V3 tableLo{-table::halfW,-table::halfL,0},tableHi{table::halfW,table::halfL,0};
        V3 blo,bhi;bboxPaths(blo,bhi);const V3 bc=(blo+bhi)*.5;
        const V3 ob0=objectCol>=0?P(objectCol,0):cue0+aimDir*.6;
        const double ysh=cue0.y>0?1:-1;
        auto potCam=[&](int jj,const Cand& cc,bool still){
            const V3 M=table::pocket(potPocket);
            V3 e=unit(flat(P(jj,potTime-.02)-P(jj,potTime-.3)));if(len(e)<.5)e=unit(flat(M-P(jj,sc.t0)));
            const V3 eye=clampRoom(M+rotZ(e,s*cc.a)*cc.d+V3{0,0,cc.h});
            for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]=M+V3{0,0,table::R}+(lookP(jj,ts[i],.1,1)-M-V3{0,0,table::R})*.55;}
            x.baseFov=35;(void)still;
        };
        auto settleCam=[&](int jj,const Cand& cc){
            const V3 Q=P(jj,std::max(sc.t1,tStopOB));V3 dv=unit(flat(Q-P(jj,sc.t0)));if(len(dv)<.5)dv=aimDir;
            const V3 eye=clampRoom(Q+rotZ(dv*-1.0,s*cc.a)*cc.d+V3{0,0,cc.h});
            for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]=lookP(jj,ts[i],.4,.5);}
            x.baseFov=40;
        };
        switch(k){
        case SceneKind::Open:case SceneKind::Manual:if(k==SceneKind::Open||style==Style::Wide34){
            const V3 F=lerp({0,0,table::R},(cue0+ob0)*.5,.5);
            const V3 eye=clampRoom(F+rotZ(aimDir*-1.0,s*c.a)*c.d+V3{0,0,c.h});
            for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]=F;}
            x.baseFov=45;x.soft=corners(tableLo,tableHi);x.softCap=70;x.softBall=objectCol;
            return;
        }
            switch(style){
            case Style::Learn:{
                const V3 F=bc+V3{0,0,table::R};const V3 eye=clampRoom(F+rotZ(aimDir*-1.0,s*c.a)*c.d+V3{0,0,c.h});
                for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]=F;}
                x.baseFov=45;x.soft=corners(blo-V3{.08,.08,0},bhi+V3{.08,.08,0});x.softCap=80;return;
            }
            case Style::Overhead:{
                const V3 eye=aspect>=1?V3{s*c.d,0,c.h}:V3{0,s*c.d,c.h};
                for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]={0,0,0};}
                x.baseFov=40;x.soft=corners(tableLo,tableHi);x.softCap=80;return;
            }
            case Style::Shooter:{
                const V3 eye=clampRoom(cue0-aimDir*c.d+V3{0,0,c.h});
                for(std::size_t i=0;i<N;++i){E[i]=eye;T[i]=cue0+aimDir*.8;}
                x.baseFov=45;x.softBall=objectCol;return;
            }
            case Style::FollowCue:{
                std::vector<double> ph(N);double prev=aim;
                for(std::size_t i=0;i<N;++i){
                    const V3 v=flat(P(cueCol,ts[i]+.5)-P(cueCol,ts[i]));
                    double a=len(v)>.03?std::atan2(v.y,v.x):prev;
                    while(a-prev>kPi)a-=2*kPi;while(a-prev<-kPi)a+=2*kPi;
                    ph[i]=a;prev=a;
                }
                ph=smoothSeq(ph,.4*kHz);
                const double lim=60/kDeg*sc.step;
                for(std::size_t i=1;i<N;++i)ph[i]=std::clamp(ph[i],ph[i-1]-lim,ph[i-1]+lim);
                for(std::size_t i=N-1;i-->0;)ph[i]=std::clamp(ph[i],ph[i+1]-lim,ph[i+1]+lim);
                ph=smoothSeq(ph,.15*kHz);
                for(std::size_t i=0;i<N;++i){
                    const V3 hd{std::cos(ph[i]),std::sin(ph[i]),0},p=P(cueCol,ts[i]);
                    E[i]=clampRoom(p-hd*c.d+V3{0,0,c.h});T[i]=p+hd*.5;
                }
                x.baseFov=45;return;
            }
            case Style::RailSide:{
                for(std::size_t i=0;i<N;++i){
                    auto S=[&](double t){
                        if(sc.subject2<0)return P(cueCol,t);
                        return lerp(P(cueCol,t),P(sc.subject2,t),smoothstep((t-(contactTime-.1))/.4));
                    };
                    const V3 p=S(ts[i]);
                    E[i]={s*c.d,std::clamp(p.y,-1.15,1.15),c.h};T[i]=p+capped((S(ts[i]+.3)-p)*.3);
                }
                x.baseFov=40;return;
            }
            case Style::PocketMeet:if(hasPot())potCam(j,c,true);else settleCam(j,c);return;
            default:break;
            }
            for(std::size_t i=0;i<N;++i){E[i]=cue0-aimDir+V3{0,0,1};T[i]=cue0;}
            return;
        case SceneKind::Stroke:
            for(std::size_t i=0;i<N;++i){
                E[i]=clampRoom(cue0-aimDir*c.d+perp*(s*c.a)+V3{0,0,c.h}+aimDir*(.22*smoothstep(prog(i))));
                T[i]=lookP(cueCol,ts[i],.3,.5)+aimDir*.3;
            }
            x.baseFov=40;x.softBall=objectCol;return;
        case SceneKind::Impact:{
            const V3 F=hasContact()?P(cueCol,contactTime):P(cueCol,sc.t0);
            for(std::size_t i=0;i<N;++i){
                const double kk=1-.05*smoothstep(prog(i));
                E[i]=clampRoom(F+rotZ(aimDir*-1.0,s*c.a)*(c.d*kk)+V3{0,0,c.h*kk});
                T[i]=F+(lookP(j,ts[i],.12,1)-F)*.6;
            }
            x.baseFov=35;x.softBall=cueCol;return;
        }
        case SceneKind::Travel:{
            const V3 P0=P(j,sc.t0),P1=P(j,sc.t1);
            V3 dir=unit(flat(P1-P0));if(len(flat(P1-P0))<.1){dir=unit(flat(rec.vel(j,sc.t0)));if(len(dir)<.5)dir=aimDir;}
            const V3 n=V3{-dir.y,dir.x,0}*s;const V3 M=hasPot()?table::pocket(potPocket):P1;
            for(std::size_t i=0;i<N;++i){
                const double pr=dot(flat(P(j,ts[i]+.15)-P0),dir)+.1;
                E[i]=clampRoom(flat(P0)+dir*pr+n*c.d+V3{0,0,c.h});
                const V3 p=P(j,ts[i]);T[i]=lookP(j,ts[i],.35,.3)+flat(M-p)*(hasPot()?.15:0.0);
            }
            x.baseFov=40;if(hasPot())x.soft={table::pocket(potPocket)};return;
        }
        case SceneKind::Pot:potCam(j,c,false);return;
        case SceneKind::Settle:settleCam(j,c);return;
        case SceneKind::Wrap:{
            // v: hướng mở đầu (8 hướng, 45°), chọn theo luật 180°; kết thúc lệch 0,45 m theo trục hợp khung
            // (16:9: lệch theo x → chiều dài bàn nằm ngang khung; 9:16: lệch theo y → chiều dài bàn dọc khung).
            const V3 B=bc;const V3 axis0=aspect>=1?V3{1,0,0}:V3{0,1,0};
            const V3 o0=rotZ(axis0,c.v*kPi/4);const V3 o1=axis0*(dot(o0,axis0)<-1e-9?-1.0:1.0);
            for(std::size_t i=0;i<N;++i){
                const double u=smoothstep((ws[i]-sc.w0)/1.2);
                E[i]=clampRoom(lerp(B+o0*c.d+V3{0,0,1.0},B+o1*.45+V3{0,0,c.h},u));T[i]=B;
            }
            x.baseFov=45;x.soft=corners(blo-V3{.06,.06,0},bhi+V3{.06,.06,0});x.softCap=72;return;
        }
        case SceneKind::BreakWide:{
            const V3 eye=c.v==0?V3{s*.3,ysh*(table::halfL+.9),c.h}:V3{s*(table::halfW+1.0),0,c.h};
            for(std::size_t i=0;i<N;++i){E[i]=clampRoom(eye);T[i]={0,0,0};}
            x.baseFov=50;x.soft=corners(tableLo,tableHi);x.softCap=78;return;
        }
        }
    }
    struct Built{std::vector<V3> eye,tgt;std::vector<double> fov;double vis=0,peakW=0,peakA=0;bool safe=true,compat=true;};
    static void angular(const std::vector<V3>& E,const std::vector<V3>& T,double step,double& peakW,double& peakA,std::vector<double>* all=nullptr){
        peakW=peakA=0;V3 prevW{};bool have=false;
        for(std::size_t i=0;i+1<E.size();++i){
            const V3 d0=unit(T[i]-E[i]),d1=unit(T[i+1]-E[i+1]);
            const V3 cr=cross(d0,d1);const double ang=std::atan2(len(cr),dot(d0,d1));
            const V3 w=unit(cr)*(ang/step*kDeg);
            peakW=std::max(peakW,len(w));if(all)all->push_back(len(w));
            if(have)peakA=std::max(peakA,len(w-prevW)/step);
            prevW=w;have=true;
        }
    }
    bool mustPoints(const Scene& sc,double t,std::vector<V3>& out)const{
        out.clear();
        int c=(sc.subject2>=0&&t>=sc.switchTime)?sc.subject2:sc.subject;
        if(c>=0&&!rec.sunkAt(c,t))out.push_back(P(c,t));
        if(sc.subject2>=0&&std::abs(t-sc.switchTime)<.4){const int o=c==sc.subject?sc.subject2:sc.subject;if(!rec.sunkAt(o,t))out.push_back(P(o,t));}
        return !out.empty();
    }
    Built build(const Scene& sc,const Cand& c,const std::vector<double>& ts,const std::vector<double>& ws,bool havePrev,V3 prevEye,const Axis& ax)const{
        Built b;std::vector<V3> E,T;Extra x;raw(sc,c,ts,ws,E,T,x);
        const std::size_t N=ts.size();
        const double sig[]={.15,.3,.5,.8,1.2,1.8};
        bool first=true;std::vector<V3> mp;
        for(double sg:sig){
            b.eye=smoothSeq(E,sg*kHz);b.tgt=smoothSeq(T,sg*kHz);
            if(first){
                first=false;int seen=0,tot=0;
                for(std::size_t i=0;i<N;++i){
                    const int cc=(sc.subject2>=0&&ts[i]>=sc.switchTime)?sc.subject2:sc.subject;
                    if(cc<0||rec.sunkAt(cc,ts[i]))continue;++tot;if(ballVisible(rec,cc,ts[i],b.eye[i]))++seen;
                }
                b.vis=tot?static_cast<double>(seen)/tot:1;
                if(b.vis<.9)return b;
            }
            angular(b.eye,b.tgt,sc.step,b.peakW,b.peakA);
            if(b.peakW<=kPlanW&&b.peakA<=kPlanA)break;
        }
        // Sửa vùng an toàn: chỗ nào bi chính cần FOV > trần, máy lùi êm dọc chính đường nhìn (hướng nhìn không đổi
        // → tốc độ góc không đổi), trọng số làm mượt + lọc max để lùi sớm và trở lại từ từ.
        for(int pass=0;pass<4;++pass){
            const double cap=std::tan((kFovMax-3)/2/kDeg);std::vector<double> wgt(N,0);double worst=0;
            for(std::size_t i=0;i<N;++i){
                double tm=0;if(mustPoints(sc,ts[i],mp))for(const V3& q:mp)tm=std::max(tm,neededTan(b.eye[i],b.tgt[i],q,aspect,kNdc));
                const double r=std::isfinite(tm)?tm/cap:4.0;worst=std::max(worst,r);if(r>1)wgt[i]=std::min(3.0,r-1+.1);
            }
            if(worst<=1)break;
            int sup=0;(void)smoothSeq(wgt,.3*kHz,false,&sup);std::vector<double> mxw(N);
            for(std::size_t i=0;i<N;++i){double m=0;const std::size_t lo=i>static_cast<std::size_t>(sup)?i-static_cast<std::size_t>(sup):0,hi=std::min(N-1,i+static_cast<std::size_t>(sup));for(std::size_t q=lo;q<=hi;++q)m=std::max(m,wgt[q]);mxw[i]=m;}
            const auto g=smoothSeq(mxw,.3*kHz,false);
            for(std::size_t i=0;i<N;++i)b.eye[i]=clampRoom(b.tgt[i]+(b.eye[i]-b.tgt[i])*(1+g[i]));
        }
        angular(b.eye,b.tgt,sc.step,b.peakW,b.peakA);
        {   // visibility on the final path
            int seen=0,tot=0;
            for(std::size_t i=0;i<N;++i){
                const int cc=(sc.subject2>=0&&ts[i]>=sc.switchTime)?sc.subject2:sc.subject;
                if(cc<0||rec.sunkAt(cc,ts[i]))continue;++tot;if(ballVisible(rec,cc,ts[i],b.eye[i]))++seen;
            }
            b.vis=tot?static_cast<double>(seen)/tot:1;
        }
        std::vector<double> need(N),want(N);
        for(std::size_t i=0;i<N;++i){
            double tm=0,tsft=0;
            if(mustPoints(sc,ts[i],mp))for(const V3& q:mp)tm=std::max(tm,neededTan(b.eye[i],b.tgt[i],q,aspect,kNdc));
            for(const V3& q:x.soft)tsft=std::max(tsft,neededTan(b.eye[i],b.tgt[i],q,aspect,kNdc));
            if(x.softBall>=0&&!rec.sunkAt(x.softBall,ts[i]))tsft=std::max(tsft,neededTan(b.eye[i],b.tgt[i],P(x.softBall,ts[i]),aspect,kNdc));
            const double fm=std::isfinite(tm)?2*std::atan(tm)*kDeg:999;
            if(fm>kFovMax)b.safe=false;
            need[i]=std::max(x.baseFov,fm);
            const double fs=std::isfinite(tsft)?std::min(2*std::atan(tsft)*kDeg,x.softCap):x.softCap;
            want[i]=std::max(need[i],fs);
        }
        int support=0;const double fs=.15*kHz;(void)smoothSeq(want,fs,false,&support);
        std::vector<double> mx(N);
        for(std::size_t i=0;i<N;++i){
            double m=0;const std::size_t lo=i>static_cast<std::size_t>(support)?i-static_cast<std::size_t>(support):0,hi=std::min(N-1,i+static_cast<std::size_t>(support));
            for(std::size_t q=lo;q<=hi;++q)m=std::max(m,want[q]);mx[i]=m;
        }
        b.fov=smoothSeq(mx,fs,false);
        for(auto& f:b.fov)f=std::clamp(f,20.0,kFovMax);
        if(havePrev)b.compat=sameSide180(axisSide(ax,prevEye),axisSide(ax,b.eye.front()));
        return b;
    }
    void planScenes(){
        for(std::size_t i=0;i<scenes.size();++i){
            Scene& sc=scenes[i];
            const int N=std::max(2,static_cast<int>(std::ceil((sc.w1-sc.w0)*kHz))+1);
            sc.step=std::max(1e-6,(sc.w1-sc.w0)/(N-1));
            std::vector<double> ts(static_cast<std::size_t>(N)),ws(static_cast<std::size_t>(N));
            for(int k=0;k<N;++k){ws[static_cast<std::size_t>(k)]=sc.w0+k*sc.step;ts[static_cast<std::size_t>(k)]=recordAt(ws[static_cast<std::size_t>(k)]);}
            const bool havePrev=i>0;const V3 prevEye=havePrev?scenes[i-1].eye.back():V3{};
            const Axis ax=actionAxis(rec,sc.t0,aim);
            Built best;double bestScore=-1e9;bool found=false;
            for(const Cand& c:candidates(sc.kind)){
                Built b=build(sc,c,ts,ws,havePrev,prevEye,ax);
                if(b.eye.empty()||b.fov.empty())continue;
                const bool ok=b.vis>=kPlanVis&&b.safe&&b.compat&&b.peakW<=kPlanW&&b.peakA<=kPlanA;
                const double score=b.vis*2+(b.safe?1:0)+(b.compat?3:0)-std::max(0.0,b.peakW-kPlanW)/50-std::max(0.0,b.peakA-kPlanA)/300;
                if(ok){best=std::move(b);found=true;break;}
                if(score>bestScore){bestScore=score;best=std::move(b);}
            }
            (void)found;
            sc.eye=std::move(best.eye);sc.target=std::move(best.tgt);sc.fov=std::move(best.fov);sc.visible=best.vis;
            if(sc.eye.empty()){sc.eye.assign(2,cue0-aimDir+V3{0,0,1});sc.target.assign(2,cue0);sc.fov.assign(2,45);sc.step=std::max(1e-6,sc.w1-sc.w0);}
        }
    }
    void finish(){
        wallDuration=wall(tB)-wall(tA);
        std::vector<double> all;peakAngular=0;minVisible=1;
        for(auto& s:scenes){
            angular(s.eye,s.target,s.step,s.peakW,s.peakA,&all);
            peakAngular=std::max(peakAngular,s.peakW);minVisible=std::min(minVisible,s.visible);
        }
        if(!all.empty()){std::sort(all.begin(),all.end());p95Angular=all[static_cast<std::size_t>(.95*static_cast<double>(all.size()-1))];}
    }
};

}  // namespace banklab::camera
