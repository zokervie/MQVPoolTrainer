#include "../BankLab/Core/MatchRules.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
using namespace banklab::match;
namespace {
int assertions=0;
void check(bool condition,const char* message){++assertions;if(!condition)throw std::runtime_error(message);}
Ball ball(int id){Ball b;b.id=id;if(id==0)b.p={0,-.9};else b.p={.2,.2+id*.06};return b;}
Event contact(int target,double time=.1){return {1,0,target,time,{}};}
Event rail(int id,int side=0,double time=.2){return {0,id,side,time,{}};}
Event pot(int id,int pocket=0,double time=.3){return {2,id,pocket,time,{}};}
Evidence shot(std::initializer_list<int> ids,std::initializer_list<Event> events,Call call={}){
    Evidence e;for(int id:ids)e.before.push_back(ball(id));e.after=e.before;e.events=events;e.call=call;
    for(const auto& event:events)if(event.kind==2)for(auto& b:e.after)if(b.id==event.a)b.sunk=true;
    return e;
}
Rules playing(Discipline d){Rules r(d);r.state.breakShot=false;r.state.ballInHand=false;r.state.headStringOnly=false;return r;}
bool spotted(const Action& a,int id){return std::find(a.spotBalls.begin(),a.spotBalls.end(),id)!=a.spotBalls.end();}
}
int main(){
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1,9},{contact(1),pot(1)}));
     check(a.accepted&&!a.foul&&a.state.currentPlayer==0,"9-ball legal pot retains turn");check(a.state.winner<0,"ordinary ball is not a win");}
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1,9},{contact(1),pot(9)}));
     check(a.state.winner==0&&!spotted(a,9),"9-ball legal combination wins");}
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1,9},{contact(9),pot(9)}));
     check(a.foul&&a.state.winner<0&&spotted(a,9),"wrong first ball cannot win nine");check(a.state.currentPlayer==1&&a.state.ballInHand,"foul gives opponent ball in hand");}
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1},{rail(0,0,.05),contact(1)}));
     check(a.foul&&a.reason=="no_rail_after_contact","a rail BEFORE contact cannot satisfy post-contact rail rule");}
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1},{contact(1),rail(0)}));
     check(!a.foul&&a.state.currentPlayer==1,"legal no-pot rail shot passes turn without ball in hand");check(!a.state.ballInHand,"no ball in hand on a legal miss");}
    {auto r=playing(Discipline::NineBall);auto a=r.complete(shot({0,1,9},{contact(1),pot(9,-1)}));
     check(a.foul&&spotted(a,9)&&a.state.winner<0,"off-table recovery event is a foul, never a made nine");}
    {auto r=playing(Discipline::NineBall);for(int i=0;i<3;++i){r.state.currentPlayer=0;auto a=r.complete(shot({0,1},{contact(1),pot(0)}));
         if(i==1)check(a.state.twoFoulWarning[0],"two-foul warning exposed before a third foul");}
     check(r.state.winner==1,"third consecutive foul loses 9-ball rack");}
    {auto r=playing(Discipline::EightBall);r.state.groups={{0,1}};for(int i=0;i<3;++i){r.state.currentPlayer=0;r.complete(shot({0,1,8,9},{contact(1),pot(0)}));}
     check(r.state.winner<0,"8-ball has no automatic three-foul rack loss");}
    {Rules r;auto e=shot({0,1,2,3,9},{contact(1),pot(9)});e.headCrossed={1};auto a=r.complete(e);
     check(!a.foul&&a.state.pendingChoice=="nine_illegal_break"&&spotted(a,9),"9-ball insufficient three-ball break is a choice, nine is spotted");
     check(!r.state.canShoot(),"pending break decision blocks shooting");a=r.resolve("accept");
     check(a.accepted&&a.state.currentPlayer==1&&!a.state.pushOutAvailable,"accept illegal break removes push-out option");}
    {Rules r;auto e=shot({0,1,2,3},{contact(1),rail(1,0,.2),rail(2,1,.21),rail(3,2,.22),rail(0,3,.23)}); // Only 3 object rails: a standard break foul.
     auto a=r.complete(e);check(a.foul&&a.state.ballInHand,"cue-ball rail is excluded from four-object-rail break count");}
    {Rules r;auto e=shot({0,1,2,3,4},{contact(1),rail(1,0,.2),rail(2,1,.21),rail(3,2,.22),rail(4,3,.23)});auto a=r.complete(e);
     check(a.state.pendingChoice=="nine_illegal_break","four rails alone can still miss nine-ball three-ball requirement");a=r.resolve("pass");
     check(a.state.currentPlayer==0&&a.state.pushOutAvailable,"pass back restores breaker push-out opportunity");}
    {Rules r;auto e=shot({0,1,2,9},{contact(1),pot(9)});e.headCrossed={1,2};auto a=r.complete(e);
     check(a.state.winner==0&&!spotted(a,9),"legal three-point 9-ball break may win");}
    {Rules r;auto e=shot({0,1,2,9},{contact(1),pot(1)});e.headCrossed={1,2};auto a=r.complete(e);
     check(a.state.pendingChoice=="nine_illegal_break","a pocketed ball crossing the line is only one object for three-ball break");}
    {auto r=playing(Discipline::NineBall);r.state.pushOutAvailable=true;Call c;c.pushOut=true;
     auto a=r.complete(shot({0,1,9},{pot(9)},c));check(!a.foul&&spotted(a,9)&&a.state.pendingChoice=="push_out","push-out suspends contact/rail requirements but spots nine");
     a=r.resolve("pass");check(a.state.currentPlayer==0&&!a.state.pushOutAvailable,"push-out may be handed back only once");}
    {auto r=playing(Discipline::NineBall);Call c;c.pushOut=true;auto a=r.complete(shot({0,1},{},c));
     check(!a.accepted&&a.reason=="push_out_unavailable"&&r.state.shotCount==0,"reject undeclared/unavailable push-out before adjudication");}
    {Rules r(Discipline::EightBall);auto a=r.complete(shot({0,1,8,9},{contact(9),pot(9)}));
     check(!a.foul&&a.state.groups[0]<0&&a.state.currentPlayer==0,"8-ball groups stay open after legal break pot");}
    {Rules r(Discipline::EightBall);auto a=r.complete(shot({0,1,8,9},{contact(8),pot(8)}));
     check(a.state.winner<0&&spotted(a,8)&&a.state.currentPlayer==0&&a.state.pendingChoice=="eight_break_eight","8 on legal break is a decision, not a win");
     a=r.resolve("rerackSelf");check(a.rerack&&a.state.breakShot&&a.state.currentPlayer==0,"breaker can choose rebreak after legal eight");}
    {Rules r(Discipline::EightBall);auto a=r.complete(shot({0,1,8,9},{contact(8),pot(8,0,.3),pot(0,1,.31)}));
     check(a.foul&&spotted(a,8)&&a.state.currentPlayer==1,"eight plus scratch on break belongs to opponent's decision");
     a=r.resolve("spotAndPlay");check(a.state.ballInHand&&a.state.headStringOnly,"eight on foul break gives head-string placement");}
    {Rules r(Discipline::EightBall);auto a=r.complete(shot({0,1,2,3,8,9},{contact(1),rail(1),rail(2,1,.21),rail(3,2,.22)}));
     check(!a.foul&&a.state.pendingChoice=="eight_illegal_break","8-ball dry insufficient break gets specified rerack choices");
     a=r.resolve("rerackOpponent");check(a.rerack&&a.state.currentPlayer==0,"incoming player can require original breaker rebreak");}
    {auto r=playing(Discipline::EightBall);auto a=r.complete(shot({0,1,8,9},{contact(8),rail(8)}));
     check(a.foul&&a.reason=="wrong_ball_first","open table does not permit eight first with both groups present");}
    {auto r=playing(Discipline::EightBall);auto a=r.complete(shot({0,8,9},{contact(8),pot(8,2)},Call{8,2,false,false}));
     check(!a.foul&&a.state.winner==0,"open table may temporarily claim an already cleared group to shoot eight");}
    {auto r=playing(Discipline::EightBall);auto a=r.complete(shot({0,8,9},{contact(8),pot(9,2)},Call{9,2,false,false}));
     check(a.foul,"temporary empty-group claim cannot be used to hit eight first while calling another group");}
    {auto r=playing(Discipline::EightBall);auto a=r.complete(shot({0,1,8,9},{contact(9),pot(1,2,.3),pot(9,3,.31)},Call{1,2,false,false}));
     check(!a.foul&&a.state.groups[0]==0&&a.state.groups[1]==1,"legal called pot, not first contact or incidental pot, determines group");}
    {auto r=playing(Discipline::EightBall);r.state.groups={{0,1}};auto a=r.complete(shot({0,1,8,9},{contact(1),pot(1),pot(8,1,.31)},Call{8,1,false,false}));
     check(a.state.winner==1,"clearing final group ball and eight together loses because group was not clear before attempt");}
    {auto r=playing(Discipline::EightBall);r.state.groups={{0,1}};auto a=r.complete(shot({0,8,9},{contact(8),pot(8,3)},Call{8,3,false,false}));
     check(a.state.winner==0,"called eight after clearing group wins");}
    {auto r=playing(Discipline::EightBall);r.state.groups={{0,1}};auto a=r.complete(shot({0,8,9},{contact(8),pot(8,2)},Call{8,3,false,false}));
     check(a.state.winner==1,"eight in wrong called pocket loses");}
    {auto r=playing(Discipline::EightBall);r.state.groups={{0,1}};auto a=r.complete(shot({0,1,8,9},{contact(1),pot(1)},Call{0,-1,true,false}));
     check(!a.foul&&a.state.currentPlayer==1&&a.spotBalls.empty(),"8-ball safety ends turn and object balls remain down");}
    {Rules r(Discipline::TenBall);auto a=r.complete(shot({0,1,10},{contact(1),pot(10)}));
     check(a.state.winner<0&&spotted(a,10)&&a.state.currentPlayer==0&&a.state.pushOutAvailable,"ten on legal break is spotted; breaker continues");}
    {auto r=playing(Discipline::TenBall);auto a=r.complete(shot({0,1,10},{contact(1),pot(10,2)},Call{10,2,false,false}));
     check(a.state.winner<0&&spotted(a,10)&&a.state.currentPlayer==0,"WPA2025: called early ten combination is spotted, not a win");}
    {auto r=playing(Discipline::TenBall);auto a=r.complete(shot({0,10},{contact(10),pot(10,4)},Call{10,4,false,false}));
     check(a.state.winner==0&&!spotted(a,10),"ten wins only as final object ball on a legal called shot");}
    {auto r=playing(Discipline::TenBall);auto a=r.complete(shot({0,1,2,10},{contact(1),pot(2,0)},Call{1,1,false,false}));
     check(a.state.pendingChoice=="ten_wrongful_pot"&&!a.foul&&a.state.currentPlayer==1,"wrongful legal pot in ten gives opponent accept/pass");
     a=r.resolve("pass");check(a.state.currentPlayer==0,"opponent can pass wrongful ten-ball pot back");}
    {auto r=playing(Discipline::TenBall);auto a=r.complete(shot({0,1,10},{contact(1),rail(0)},Call{0,-1,true,false}));
     check(!a.accepted&&r.state.shotCount==0,"WPA2025 ten has no safety call");}
    {auto r=playing(Discipline::Rotation15);r.state.scores[0]=60;auto a=r.complete(shot({0,1,15},{contact(1),pot(1)}));
     check(a.state.winner==0&&a.state.scores[0]==61,"named rotation practice variant scores ball values to61");}
    {auto r=playing(Discipline::Rotation15);auto a=r.complete(shot({0,1,15},{contact(1),pot(15),pot(0,1,.31)}));
     check(a.foul&&spotted(a,15)&&a.state.scores[0]==0,"rotation practice foul pots are spotted without score");}
    for(auto d:{Discipline::EightBall,Discipline::NineBall,Discipline::TenBall,Discipline::Rotation15}){
        Rules r(d);const auto a=r.rack(12345),b=r.rack(12345);check(a.size()==b.size(),"repeatable seeded rack");
        for(std::size_t i=0;i<a.size();++i){check(a[i].id==b[i].id&&a[i].p.x==b[i].p.x&&a[i].p.y==b[i].p.y,"same seed preserves full rack");
            for(std::size_t j=0;j<i;++j)check((a[i].p-a[j].p).length()>=.05715-1e-9,"rack balls never overlap");}
        if(d==Discipline::EightBall){check(a[5].id==8,"eight in rack middle");
            check((a[11].id>=1&&a[11].id<=7&&a[15].id>=9)||(a[15].id>=1&&a[15].id<=7&&a[11].id>=9),"one randomized group each lower corner");}
        if(d==Discipline::NineBall){check(a[1].id==1&&a[5].id==9&&std::abs(a[5].p.y-.635)<1e-12,"nine on foot spot and one at apex");}
        if(d==Discipline::TenBall)check(a[1].id==1&&a[5].id==10,"ten rack apex/middle constraints");
    }
    {Rules r;auto e=shot({0,1},{contact(1),rail(0)});e.before.push_back(ball(1));auto a=r.complete(e);check(!a.accepted&&r.state.shotCount==0,"duplicate IDs rejected without mutating state");}
    {Rules r;auto e=shot({0,1,2,9},{contact(1),pot(9)});e.headCrossed={1,2};e.before[0].p={0,0};auto a=r.complete(e);
     check(a.foul&&a.state.ballInHand&&a.state.winner<0&&spotted(a,9),"break starts strictly behind head string; invalid placement cannot win");}
    {auto r=playing(Discipline::NineBall);auto e=shot({0,1},{contact(1),rail(0)});e.after.pop_back();
     auto a=r.complete(e);check(!a.accepted,"missing after-state IDs reject malformed evidence");}
    {auto r=playing(Discipline::NineBall);auto e=shot({0,1},{contact(1),rail(0)});e.before[0].p.x=std::nan("");
     auto a=r.complete(e);check(!a.accepted,"nonfinite positions reject malformed evidence");}
    {Rules r;auto e=shot({0,1,9},{contact(1),pot(9)});e.headCrossed={2,3};auto a=r.complete(e);
     check(!a.accepted,"nonexistent IDs cannot manufacture a legal three-point break");}
    {auto r=playing(Discipline::NineBall);r.state.ballInHand=true;auto e=shot({0,1},{contact(1),rail(0)});e.before[1].p={.05715,-.9};
     auto a=r.complete(e);check(a.foul&&a.reason=="bad_cue_ball_placement","ball in hand must not be placed touching an object ball");}
    std::cout<<"PASS MatchRules: "<<assertions<<" checks; WPA8/9/10 event adjudication, break choices, push-out, called shots, three-foul warning, seeded racks; Rotation15 named practice variant\n";
}
