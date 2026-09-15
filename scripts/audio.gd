class_name OrdoAudio
extends Node
const EFFECTS=["impact","heavy","launch","death","hurt","shield","ice","wind","boss","joy","mock","anger","surprise","ui","ready","cancel","pickup","snare","heal","clear","victory","lose","ability"]
var effects:Dictionary={}
var voices:Array=[]
var menu_music:AudioStreamPlayer
var interlude_music:AudioStreamPlayer
var fire:AudioStreamPlayer
var slide:AudioStreamPlayer
var levels:=Vector2.ZERO
var clock:=0.0
var last_play:Dictionary={}
var silent:=false
var rng:=RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed=7219
	for effect in EFFECTS:effects[effect]=load("res://assets/audio/%s.wav"%effect)
	effects["steam"] = steam_sound()
	for i in 16:
		var voice:=AudioStreamPlayer.new();add_child(voice);voices.append(voice)
	menu_music=loop_player("menu");interlude_music=loop_player("interlude")
	fire=loop_player("fire");slide=loop_player("slide")
func loop_player(file: String) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new();add_child(player)
	var stream:AudioStreamWAV=load("res://assets/audio/%s.wav"%file).duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/4
	player.stream=stream;player.volume_db=-80;return player
func step(dt:float,menu:bool,phase:String,fire_alive:bool,motion:float,muted:bool) -> void:
	clock+=dt;silent=muted
	var desired:=Vector2(1,0) if menu else (Vector2(0,1) if phase in ["clear","reward","win"] else Vector2.ZERO)
	levels=levels.lerp(Vector2.ZERO if muted else desired,1.0-exp(-dt*2.2))
	for pair in [[menu_music,levels.x],[interlude_music,levels.y]]:
		if float(pair[1])>0.001:
			if not pair[0].playing:pair[0].play()
		elif pair[0].playing:pair[0].stop()
	if not muted and fire_alive:
		if not fire.playing:fire.play()
	elif fire.playing:fire.stop()
	if not muted and motion>0.15:
		if not slide.playing:slide.play()
	elif slide.volume_db < -65 and slide.playing:slide.stop()
	menu_music.volume_db=linear_to_db(maxf(0.0001,levels.x)) - 19
	interlude_music.volume_db=linear_to_db(maxf(0.0001,levels.y)) - 22
	fire.volume_db=-80 if muted or not fire_alive else -32
	var slide_target:float=-80 if muted or motion<0.15 else -33+clampf(motion,0,12)*0.5
	slide.volume_db=lerpf(slide.volume_db,slide_target,1.0-exp(-dt*12))
	if muted:
		for voice in voices:voice.stop()
func play_sound(name:String,volume:float=-12.0,player_id:int=-1) -> void:
	if silent:return
	if name=="chime":name="pickup"
	if not effects.has(name):return
	var cooldown:=0.12 if name in ["joy","mock","anger"] else 0.035
	var cooldown_key:="ready_%d"%player_id if name=="ready" else name
	if clock-float(last_play.get(cooldown_key,-10.0))<cooldown:return
	last_play[cooldown_key]=clock
	for voice in voices:
		if not voice.playing:
			voice.stream=effects[name];voice.volume_db=volume
			voice.pitch_scale=1.0 if name=="ready" else rng.randf_range(0.96,1.04)
			voice.play();return
func stop() -> void:
	silent=true
	for voice in voices+[menu_music,interlude_music,fire,slide]:
		if is_instance_valid(voice):voice.stop();voice.stream=null
func _exit_tree() -> void:stop()

static func steam_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050
	var samples := PackedByteArray(); samples.resize(22050*2)
	var noise := RandomNumberGenerator.new(); noise.seed = 83711
	var low := 0.0
	for i in 22050:
		var t := float(i)/22050.0
		var white := noise.randf_range(-1,1)
		low = lerpf(low,white,.17)
		var envelope := (1.0-exp(-t*140.0))*exp(-t*4.8)*(1.0-smoothstep(.7,1.0,t))
		var sample := (white*.40+low*.60)*envelope*.65
		samples.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	stream.data=samples
	return stream
