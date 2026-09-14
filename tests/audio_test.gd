extends SceneTree
const Audio=preload("res://scripts/audio.gd")
var failures:=0
var checks:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var audio:=Audio.new();root.add_child(audio);await process_frame
	check(audio.effects.size()==27,"All event sounds and four player cues load")
	check(absf(audio.menu_music.stream.get_length()-64.0)<0.01,"Menu loop is 64 seconds")
	check(absf(audio.interlude_music.stream.get_length()-32.0)<0.01,"Interlude loop is 32 seconds")
	for i in 180:audio.step(1.0/60,true,"plan",true,0,false)
	check(audio.levels.x>0.99 and audio.levels.y<0.01,"Menu fades in only its theme")
	for i in 180:audio.step(1.0/60,false,"resolve",true,5,false)
	check(audio.levels.length()<0.01,"Music yields to battle effects")
	for i in 180:audio.step(1.0/60,false,"reward",true,0,false)
	check(audio.levels.y>0.99,"Reward phase fades in interlude")
	for player in 4:
		audio.play_sound("ready",-12.0,player)
		check(audio.voices[player].playing and audio.voices[player].stream==audio.effects["ready_%d"%player],"Each player gets their own simultaneous ready cue")
		check(audio.voices[player].pitch_scale==1.0,"Ready signature keeps its tuning")
	check(audio.voices.filter(func(v):return v.playing).size()==4,"One player's cooldown does not suppress another")
	for player in 3:
		check(audio.effects["ready_%d"%player].data!=audio.effects["ready_%d"%(player+1)].data,"Player cues have different audio")
	audio.step(0.1,false,"reward",true,0,true);audio.play_sound("ready")
	for player in 4:audio.play_sound("ready",-12.0,player)
	check(not audio.voices.any(func(v):return v.playing),"Mute suppresses effects")
	audio.stop();check(not audio.menu_music.playing and not audio.fire.playing,"Shutdown stops loops")
	audio.queue_free();await process_frame;await create_timer(0.15).timeout
	print("AUDIO: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
