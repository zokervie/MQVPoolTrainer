import Foundation

@main struct ReplayRecordingTests {
    struct Failure: Error {let message:String}
    static func main() throws {
        var checks=0
        func check(_ value:Bool,_ message:String)throws{guard value else{throw Failure(message:message)};checks+=1}
        func invalid(_ recording:ShotRecording)throws{
            var rejected=false;do{try recording.validate()}catch{rejected=true}
            try check(rejected,"invalid preparation must not enter archive")
        }
        let ball=BallState(id:0,x:0,y:0)
        let begin=ReplayAimSample(time:0,angle:0.3,side:0.2,top:0.3,pull:0,mode:2,zoom:1,orbit:0,pitch:0.8,aimPitch:0.5,cameraYaw:0,elevation:0,cueType:0)
        var end=begin;end.time=8;end.angle=1.2;end.pull=0.8
        let impact:[String:NSNumber] = ["kind":0,"a":0,"b":1,"time":1,"x":0,"y":0]
        let recording=ShotRecording(frames:[[ball],[ball]],frameTimes:[0,4],events:[impact],preparation:[begin,end])
        try recording.validate()
        let data=try JSONEncoder().encode(recording)
        let decoded=try JSONDecoder().decode(ShotRecording.self,from:data)
        try check(decoded.preparation?.last?.time==8,"eight-second preparation survives disk codec")
        try check(decoded.preparation?.last?.pull==0.8,"stroke pull survives disk codec")
        try check(decoded.frameTimes==[0,4] && decoded.events[0]["time"]?.doubleValue==1,"pre-roll must not shift native physics/event clock")
        var legacy=try JSONSerialization.jsonObject(with:data) as! [String:Any]
        legacy.removeValue(forKey:"preparation")
        let old=try JSONDecoder().decode(ShotRecording.self,from:JSONSerialization.data(withJSONObject:legacy))
        try old.validate();try check(old.preparation==nil,"legacy archives remain readable")
        var bad=end;bad.time=9
        try invalid(ShotRecording(frames:[[ball]],frameTimes:[0],events:[],preparation:[begin,bad]))
        bad=end;bad.zoom = .nan
        try invalid(ShotRecording(frames:[[ball]],frameTimes:[0],events:[],preparation:[begin,bad]))
        var reversed=begin;reversed.time=0.5
        try invalid(ShotRecording(frames:[[ball]],frameTimes:[0],events:[],preparation:[begin,end,reversed]))
        // 0.59: slow motion only around the FIRST object pot (0.55 s before … 0.20 s after), never a blanket ending slowdown.
        try check(ReplayDirector.keyMomentRate(time:8,keyTime:nil)==1,"no pot: the replay runs at 1x")
        try check(ReplayDirector.keyMomentRate(time:4.5,keyTime:5)==0.5,"just before the pot is slowed")
        try check(ReplayDirector.keyMomentRate(time:5.15,keyTime:5)==0.5,"the drop itself is slowed")
        try check(ReplayDirector.keyMomentRate(time:4.4,keyTime:5)==1 && ReplayDirector.keyMomentRate(time:5.25,keyTime:5)==1,"outside the window: 1x")
        try check(ReplayDirector.keyMomentRate(time:5,keyTime:.nan)==1,"a broken event time never slows the replay")
        let plan=ReplayDirector.Plan(duration:10,events:[],initialAngle:0)
        try check(plan.frame(time:8,balls:[ball]).slowMotion==1,"no pot: no ending slowdown any more")
        let pot1:[String:NSNumber]=["kind":2,"a":3,"b":1,"time":4,"x":0,"y":0], pot2:[String:NSNumber]=["kind":2,"a":5,"b":2,"time":7,"x":0,"y":0]
        let potPlan=ReplayDirector.Plan(duration:10,events:[impact,pot2,pot1],initialAngle:0)
        try check(potPlan.frame(time:3.8,balls:[ball]).slowMotion==0.5,"first pot (by time, not log order) is the key moment")
        try check(potPlan.frame(time:6.8,balls:[ball]).slowMotion==1,"a second pot is not slowed")
        print("PASS ReplayRecording: \(checks) checks; pre-roll archive compatibility, native clock isolation, one slow-motion moment (first pot)")
    }
}
