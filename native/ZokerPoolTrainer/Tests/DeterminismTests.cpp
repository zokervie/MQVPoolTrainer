#include "../BankLab/Core/Physics.hpp"
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

using namespace banklab;
namespace {
struct Fixture { const char* name; V2 cue, object; double angle,speed,side,top,elevation; };
const Fixture fixtures[] = {
    {"slow-roll",{0,-.7},{.4,.7},pi/2,.5,0,.4,0},
    {"center-contact",{0,-.7},{0,-.1},pi/2,2,0,0,0},
    {"draw-contact",{0,-.7},{0,-.1},pi/2,2,0,-.5,0},
    {"follow-contact",{0,-.7},{0,-.1},pi/2,2,0,.5,0},
    {"left-cut",{0,-.7},{.03,-.1},pi/2,2,-.3,0,0},
    {"right-cut",{0,-.7},{-.03,-.1},pi/2,2,.3,0,0},
    {"multi-rail-side",{0,-.7},{.3,.3},.35,4,.4,.2,0},
    {"near-pocket",{.52,1.06},{-.3,-.3},.7,1.5,-.2,0,0},
    {"experimental-jump",{.1,-.8},{.1,-.6},pi/2,5,0,0,55},
    {"experimental-masse",{0,-.7},{.3,.6},pi/2,2,.4,0,70}
};
void mix(std::uint64_t &hash, std::uint64_t value) {
    for(int i=0;i<8;++i){hash^=(value>>(8*i))&255;hash*=1099511628211ULL;}
}
void number(std::uint64_t &hash,double value) {
    if(!std::isfinite(value))throw std::runtime_error("nonfinite state");
    if(value==0)value=0; // Normalize negative zero, never serialize struct padding.
    std::uint64_t bits=0;std::memcpy(&bits,&value,sizeof bits);mix(hash,bits);
}
void state(std::uint64_t &hash,const World &w) {
    number(hash,w.time);mix(hash,w.balls.size());
    for(const auto &b:w.balls) {
        mix(hash,b.id);mix(hash,b.sunk);mix(hash,b.rails);
        for(double v:{b.p.x,b.p.y,b.v.x,b.v.y,b.w.x,b.w.y,b.spin,
                      b.height,b.vertical,b.rotation.x,b.rotation.y,b.rotation.z,b.rotation.w})number(hash,v);
    }
}
std::uint64_t simulate(const Fixture &f) {
    Config c;c.coupledCushions=true;c.experimental3D=f.elevation>0;
    c.cueElevationDegrees=f.elevation;c.cueType=f.elevation==55 ? 1:0;
    Ball a;a.id=0;a.p=f.cue;Ball b;b.id=1;b.p=f.object;
    World w(c);w.reset({a,b});w.strike(f.angle,f.speed,f.side,f.top);
    std::uint64_t hash=14695981039346656037ULL;
    for(int i=0;i<5760;++i){w.step();if(i%120==0)state(hash,w);}
    state(hash,w);mix(hash,w.events.size());
    for(const auto &e:w.events){mix(hash,e.kind);mix(hash,e.a);mix(hash,e.b);for(double v:{e.time,e.p.x,e.p.y,e.impact})number(hash,v);}
    return hash;
}
}
int main() {
    for(const auto &f:fixtures) {
        const auto expected=simulate(f);
        for(int repeat=1;repeat<100;++repeat)
            if(simulate(f)!=expected)throw std::runtime_error(std::string("Repeatability failed: ")+f.name);
        std::cout<<"PASS deterministic "<<f.name<<" repeats=100 signature="<<std::hex<<expected<<std::dec<<'\n';
    }
    auto changed=fixtures[0];changed.speed+=.1;
    if(simulate(changed)==simulate(fixtures[0]))throw std::runtime_error("Signature insensitive to changed input");
    std::cout<<"PASS: 10 synthetic fixtures x100 repeats, full state/event signatures; same binary/platform only, not measured-table accuracy\n";
}
