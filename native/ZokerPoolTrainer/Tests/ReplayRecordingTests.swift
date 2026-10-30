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
        try check(ReplayDirector.endingRate(time:-1,duration:10)==1,"preparation remains normal speed")
        try check(ReplayDirector.endingRate(time:6.99,duration:10)==1,"early motion remains normal speed")
        try check(ReplayDirector.endingRate(time:7,duration:10)==0.48,"last three seconds slow down")
        try check(ReplayDirector.endingRate(time:0,duration:2)==0.48,"short shots slow without negative onset")
        try check(ReplayDirector.endingRate(time:10,duration:10)==1,"end hold does not extend indefinitely")
        let plan=ReplayDirector.Plan(duration:10,events:[],initialAngle:0)
        try check(plan.frame(time:8,balls:[ball]).slowMotion==0.48,"director applies final slowdown without needing a pot")
        print("PASS ReplayRecording: \(checks) checks; pre-roll archive compatibility, native clock isolation, final-three-second slowdown")
    }
}
