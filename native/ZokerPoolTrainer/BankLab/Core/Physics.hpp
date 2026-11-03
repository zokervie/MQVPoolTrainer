#pragma once
#include <vector>
#include <cmath>
#include <algorithm>
#include <array>

namespace banklab {
constexpr double pi=3.14159265358979323846;
struct V2 {
    double x=0,y=0;
    V2 operator+(V2 b)const{return{x+b.x,y+b.y};}
    V2 operator-(V2 b)const{return{x-b.x,y-b.y};}
    V2 operator*(double s)const{return{x*s,y*s};}
    V2 operator/(double s)const{return{x/s,y/s};}
    V2& operator+=(V2 b){x+=b.x;y+=b.y;return *this;}
    V2& operator-=(V2 b){x-=b.x;y-=b.y;return *this;}
    double dot(V2 b)const{return x*b.x+y*b.y;}
    double length()const{return std::hypot(x,y);}
    V2 unit()const{double n=length();return n>1e-12?*this/n:V2{};}
    V2 perp()const{return{-y,x};}
};
struct Config {
    double width=1.27,length=2.54,radius=.028575,mass=.17;
    double sliding=.20,rolling=.012,spinDecay=7.0;
    // Ma sát bi–bi phụ thuộc tốc độ trượt tại điểm tiếp xúc (Alciatore TP A.14, khớp dữ liệu Marlow):
    // μ(v) = a + b·e^(−c·v), a = 0,00995, b = 0,108, c = 1,088 s/m. `ballFriction` là μ khi v → 0 (= a + b).
    // Trước 0.14 dùng hằng số 0,035 → throw cú chậm chỉ ~2° thay vì 4–6° (Tests/LiteratureTests.cpp).
    double ballRestitution=.94,ballFriction=.118,ballFrictionMin=.00995,ballFrictionDecay=1.088;
    double ballFrictionAt(double slip)const{double lo=std::min(ballFrictionMin,ballFriction);return lo+(ballFriction-lo)*std::exp(-ballFrictionDecay*slip);}
    // Va chạm cơ–bi (Alciatore TP A.30/A.31). `speed` truyền vào strike() là tốc độ bi khi đánh TÂM;
    // đánh lệch tâm d thì bi đi chậm hơn: v = speed·(1+m/M)/(1+m/M+2,5d²). Squirt theo khối lượng đầu cơ mₑ.
    // Khối lượng cơ theo cueType (0 thường 19 oz, 1 nhảy, 2 phá); mₑ là GIẢ ĐỊNH (ngọn chuẩn ~7 g), chưa đo.
    double cueMass()const{return cueType==1?.31:cueType==2?.56:.54;}
    double cueEndMass()const{return cueType==1?.012:cueType==2?.010:.007;}
    // Squirt (TP A.31) on/off. Core default ON keeps the literature model and old replays exact.
    // The app turns it OFF for Đánh/Phá so the ball leaves along the aim line and the player
    // judges the contact angle by eye (owner decision 03/11/2026); ON for Jump/Massé.
    bool squirtEnabled=true;
    // Massé: solve cue impulse, ball rotation and slate reaction TOGETHER (CueSlateContact.hpp) instead of
    // "cue first, slate after". Default off; the app turns it on for the Massé shot kind. The cue keeps a
    // finite mass (cueMass()) and restitution .35 [assumed, from build 28; not fitted to video].
    bool masseCoupledContact=false;
    // 0.21 (owner decision 03/11): with squirtRampDegrees > 0 the cue ball leaves on the aim line while the cue
    // is level; squirt fades in with elevation, full at squirtRampDegrees [design ramp, avoids a jump at 0 deg].
    // 0 = literature behaviour (squirt at every elevation), which keeps old regressions exact.
    double squirtRampDegrees=0;
    double squirtScale()const{return squirtRampDegrees<=0?1.0:std::clamp(cueElevationDegrees/squirtRampDegrees,0.0,1.0);}
    // Cue tip: 0 medium (default, unchanged physics), 1 soft (massé), 2 hard (jump/break phenolic).
    // A soft tip does NOT give more spin for the same contact point; it lets the tip hold further from centre
    // before a miscue (larger maximum offset -> more maximum spin). A hard tip returns more energy.
    // Offsets and efficiency ratios are ASSUMED (tip restitution .70/.75/.86 relative, TP A.30 (1+e) scaling).
    int tipProfile=0;
    double tipSpeedFactor()const{return tipProfile==1?.971:tipProfile==2?1.063:1.0;}
    double tipMaxOffset(bool elevated)const{const double base=elevated?.60:.70;return base+(tipProfile==1?.08:tipProfile==2?-.05:0.0);}
    // Break cue: heavier stroke the player can deliver with it [design gain]. Level 30 (8 m/s) x 1.4 x hard tip
    // ~= 11.9 m/s, inside published pro break speeds (~25-30 mph = 11-13 m/s).
    double breakSpeedGain=1.0;
    double cueSpeedGain()const{return tipSpeedFactor()*(cueType==2?breakSpeedGain:1.0);}
    static constexpr double maxBallSpeed=12.5;
    double masseCueRestitution=.35;
    double railRestitution=.82,railFriction=.16;
    // Rail tangential restitution (grip-slip, CushionContact3D.hpp). 0 = rigid stick model (pre-0.21, keeps old
    // regressions exact). The app sets railTangentialRestitution from the clip fit in Tests/ReverseZigzagTests.cpp.
    double railTangentialRestitution=0;
    bool individualRails=false;
    std::array<double,4> railBounce{{.82,.82,.82,.82}},railGrip{{.16,.16,.16,.16}};
    double bounce(int i)const{return individualRails&&i>=0&&i<4?railBounce[i]:railRestitution;}
    double grip(int i)const{return individualRails&&i>=0&&i<4?railGrip[i]:railFriction;}
    // Optional research response; zero preserves v0.9 behaviour.
    double railSpeedSensitivity=0;
    bool coupledCushions=false; // Native app enables A1; legacy regressions remain selectable.
    bool experimental3D=false;
    double cueElevationDegrees=0;
    int cueType=0; // 0 playing, 1 jump, 2 break; illustrative Zoker profiles.
    double slateRestitution=.50,slateFriction=.20;
    // Contact height relative to ball centre divided by radius.
    double railHeight=.27;
    double railNoseHeightMeters()const{return radius*(1+railHeight);}
    double railRadius()const{return radius*std::sqrt(1-railHeight*railHeight);}
};
struct Rotation {double x=0,y=0,z=0,w=1;};
struct Ball { int id=0;V2 p{},v{},w{};double spin=0;bool sunk=false;int rails=0;Rotation rotation{}; double height=0,vertical=0; };
struct Segment {V2 a,b;int rail;};
struct Event {int kind;int a,b;double time;V2 p;double impact=0;}; // 0 cushion, 1 ball, 2 pocket
struct PredictionSample {int id;double time;V2 p;bool sunk;double height=0;};
/// Kết quả đầy đủ của một cú mô phỏng trên bản sao (Coach: phản thực tế, không đụng world thật).
struct Outcome {std::vector<Event> events;std::vector<Ball> balls;double time=0;bool settled=false;};
class World {
public:
    Config config;
    std::vector<Ball> balls;
    std::vector<Segment> segments;
    std::vector<Event> events;
    double time=0;
    static constexpr double stepSize=1.0/960.0;
    explicit World(Config c={}):config(c){buildRails();}
    void buildRails();
    void reset(std::vector<Ball> layout){balls=layout;previousPresentation.clear();events.clear();time=0;accumulator=0;for(auto&b:balls){b.v={};b.w={};b.spin=0;b.rails=0;b.rotation={};b.height=0;b.vertical=0;}}
    void strike(double angle,double speed,double side,double top);
    void advance(double elapsed);
    void step(double dt=stepSize);
    bool moving()const;
    std::vector<V2> idealGuide(V2 start,double angle,int count)const;
    std::vector<PredictionSample> predict(double angle,double speed,double side,double top,double seconds=12)const;
    Outcome simulate(double angle,double speed,double side,double top,double seconds=60)const;
    static void cushionResponse(Ball& b,const Config& config,V2 n,int rail);
    std::vector<Ball> presentation()const;
    static double energy(const Ball& b,const Config& c);
    /// Góc squirt (rad, ≥ 0) theo TP A.31; side = độ lệch ngang / R.
    static double squirtAngle(double side,double ballMass,double endMass);
private:
    double accumulator=0;
    std::vector<Ball> previousPresentation;
    size_t presentationEventCount=0;
    void strikeElevated(double angle,double speed,double side,double top);
    void stepElevated(double dt);
    void cloth(Ball&b,double dt);
    void ballCollision(Ball&a,Ball&b);
    void railCollision(Ball&b,const Segment&s);
    bool pocket(Ball&b);
};
}
