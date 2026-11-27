extends RefCounted
## Personality-driven conversational engine for an individual resident.
var resident_id := ""
var traits: Dictionary = {}
var voice_profile: Dictionary = {}
var conversation_memory: Array[Dictionary] = []
var known_topics: Dictionary = {}
var opinions: Dictionary = {}
var speaking_style := "balanced"
var last_utterance := ""
var dialogue_count := 0
var _rng := RandomNumberGenerator.new()

func initialize(identity: String, resident_traits: Dictionary, profile: Dictionary = {}) -> void:
	resident_id = identity
	traits = resident_traits.duplicate(true)
	_rng.seed = int(abs(hash(identity + ":voice")))
	speaking_style = _choose_style()
	voice_profile = {"style":speaking_style,"formality":_rng.randf_range(0.15,0.9),"humor":float(traits.get("sociability",0.5))*_rng.randf_range(0.5,1.0),"verbosity":_rng.randf_range(0.45,1.0),"directness":float(traits.get("courage",0.5))*_rng.randf_range(0.65,1.0),"profile_name":str(profile.get("name",identity))}

func _choose_style() -> String:
	var kindness := float(traits.get("kindness",0.5))
	var sociability := float(traits.get("sociability",0.5))
	var ambition := float(traits.get("ambition",0.5))
	var curiosity := float(traits.get("curiosity",0.5))
	if kindness > 0.78 and sociability > 0.65:
		return "warm"
	if ambition > 0.78:
		return "driven"
	if curiosity > 0.78:
		return "curious"
	if sociability < 0.3:
		return "reserved"
	if float(traits.get("courage",0.5)) > 0.78:
		return "bold"
	return "balanced"

func get_style_snapshot() -> Dictionary:
	return voice_profile.duplicate(true)

func remember_conversation(other_id: String, topic: String, my_line: String, their_line: String, mood: String = "neutral") -> void:
	conversation_memory.append({"other_id":other_id,"topic":topic,"my_line":my_line,"their_line":their_line,"mood":mood,"turn":dialogue_count})
	while conversation_memory.size() > 60:
		conversation_memory.pop_front()
	known_topics[topic] = int(known_topics.get(topic,0))+1

func recall_conversations(topic: String = "", limit: int = 5) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in conversation_memory:
		if topic.is_empty() or topic.to_lower() in str(entry.get("topic","")).to_lower():
			results.append(entry.duplicate(true))
	results.reverse()
	if results.size() > limit:
		results.resize(limit)
	return results

func set_opinion(topic: String, opinion: String, strength: float = 0.5) -> void:
	opinions[topic] = {"opinion":opinion,"strength":clampf(strength,0.0,1.0)}

func get_opinion(topic: String) -> Dictionary:
	return opinions.get(topic,{"opinion":"I haven't made up my mind yet.","strength":0.0}).duplicate(true)

func generate_greeting(other_name: String, relationship: float = 0.0, time_of_day: String = "day") -> String:
	var greetings: Array[String] = []
	match speaking_style:
		"warm":
			greetings = ["Hey, %s! I'm glad to see you. How have you been?" % other_name,"Hello, %s! It's always nice to meet someone familiar." % other_name]
		"driven":
			greetings = ["Hi, %s. Busy day ahead, but let's talk." % other_name,"Hello. What's the most important thing happening today?"]
		"curious":
			greetings = ["Oh, hi %s! What interesting thing have you discovered lately?" % other_name,"Hello! I was just wondering what people are talking about today."]
		"reserved":
			greetings = ["Hello, %s." % other_name,"Oh, hi. How are things going?"]
		"bold":
			greetings = ["Hey, %s! What's going on around here?" % other_name,"Hi! Tell me what's happening."]
		_:
			greetings = ["Hi, %s. How's your day going?" % other_name,"Hello! Nice to see you."]
	if relationship > 0.55:
		greetings.append("Good to see you again, %s. I've missed our conversations." % other_name)
	if time_of_day == "night":
		greetings.append("Still awake, %s? It's getting late.")
	return _finish(greetings[_rng.randi_range(0,greetings.size()-1)])

func answer_question(question: String, context: Dictionary = {}) -> String:
	var normalized := question.strip_edges().to_lower()
	var name := str(context.get("speaker_name","friend"))
	var mood := str(context.get("mood","neutral"))
	if normalized.is_empty():
		return generate_greeting(name,float(context.get("relationship",0.0)),str(context.get("time_of_day","day")))
	if _contains_any(normalized,["how are you","how's it going","qandaysan","qalaysan","yaxshimisan"]):
		return _mood_answer()
	if _contains_any(normalized,["what is your name","who are you","isming nima","kimsan"]):
		return "I'm %s. I'm a %s, and I have my own plans and interests." % [str(context.get("my_name",resident_id)),str(context.get("occupation","resident"))]
	if _contains_any(normalized,["what do you think","fikring","nima deb o'ylaysan","nima deb oylaysan"]):
		return _opinion_answer(str(context.get("topic","life")))
	if _contains_any(normalized,["family","oila","farzand","children"]):
		return _family_answer(context)
	if _contains_any(normalized,["work","job","ish","kasb","career"]):
		return _work_answer(context)
	if _contains_any(normalized,["city","shahar","neighborhood","mahalla"]):
		return _city_answer(context)
	if _contains_any(normalized,["future","kelajak","dream","orzu","goal","maqsad"]):
		return _goal_answer(context)
	if _contains_any(normalized,["sorry","kechir","uzr"]):
		return _apology_answer()
	if _contains_any(normalized,["thank","rahmat"]):
		return _thanks_answer()
	if _contains_any(normalized,["help","yordam"]):
		return _help_answer()
	if _contains_any(normalized,["remember","eslaysan","eslaysiz"]):
		return _memory_answer(str(context.get("other_id","")))
	return _topic_response(question,context,mood)

func generate_follow_up(topic: String, other_line: String = "") -> String:
	var options: Array[String] = []
	if speaking_style == "curious":
		options = ["What made you interested in %s?" % topic,"How did you find that out?","What happened next?"]
	elif speaking_style == "warm":
		options = ["I'd like to hear more about that.","How did that make you feel?","Is there anything I can do to help?"]
	elif speaking_style == "driven":
		options = ["What's the next step?","How could we make that better?","What result are you aiming for?"]
	elif speaking_style == "reserved":
		options = ["I see. Tell me a little more.","That makes sense.","What happened after that?"]
	else:
		options = ["Really? Tell me more.","What do you think will happen next?","I hadn't thought about it that way."]
	return _finish(options[_rng.randi_range(0,options.size()-1)])

func _topic_response(question: String, context: Dictionary, mood: String) -> String:
	var options: Array[String] = []
	var topic := str(context.get("topic","that"))
	var kindness := float(traits.get("kindness",0.5))
	var curiosity := float(traits.get("curiosity",0.5))
	if mood in ["sad","worried","stressed"]:
		options = ["That sounds difficult. Do you want to talk about it?","I hope things get easier. Have you got someone to support you?","I can listen if you need to get something off your chest."]
	elif _rng.randf() < curiosity:
		options = ["That's an interesting question. What got you thinking about it?","I don't know everything about that, but I'd like to learn.","I have a few thoughts, though I'd like to hear yours too."]
	elif kindness > 0.68:
		options = ["I understand what you mean. How can I help?","That's worth thinking about. I hope it works out well.","I appreciate you telling me."]
	else:
		options = ["I'm not completely sure. What do you think?","People see that differently. What's your view?","I haven't looked into it enough to have a strong opinion."]
	return _finish(options[_rng.randi_range(0,options.size()-1)])

func _mood_answer() -> String:
	if speaking_style == "warm":
		return "I'm doing alright, thanks for asking. How are you holding up?"
	if speaking_style == "driven":
		return "I'm focused and keeping busy. There is always something to improve."
	if speaking_style == "reserved":
		return "I'm okay, thank you. Just taking things one step at a time."
	if speaking_style == "curious":
		return "Pretty good! My mind is full of questions today."
	return "I'm doing fine, thanks. How about you?"

func _opinion_answer(topic: String) -> String:
	var known := get_opinion(topic)
	if float(known.get("strength",0.0)) > 0.25:
		return "On %s, I tend to think %s" % [topic,str(known.get("opinion",""))]
	if speaking_style == "bold":
		return "I'll be honest: I have a view on %s, but I'm open to evidence." % topic
	if speaking_style == "curious":
		return "I'm still learning about %s. What have you found out?" % topic
	return "I haven't settled my opinion about %s yet. What do you think?" % topic

func _family_answer(context: Dictionary) -> String:
	var count := int(context.get("children",0))
	if count > 0:
		return "Family matters to me. I have %d child(ren), and they keep me busy." % count
	return "Family is important, though everyone's situation is different. What about yours?"

func _work_answer(context: Dictionary) -> String:
	var job := str(context.get("occupation","resident"))
	if speaking_style == "driven":
		return "I work as a %s. I want to keep improving and build something meaningful." % job
	if speaking_style == "warm":
		return "I work as a %s. It has its challenges, but I try to do right by people." % job
	return "I'm a %s. Some days are busy, but that's life." % job

func _city_answer(context: Dictionary) -> String:
	var city := str(context.get("city","this city"))
	if speaking_style == "curious":
		return "There is always something new to discover in %s. Have you explored it much?" % city
	return "I live in %s. It has good days and difficult days, like anywhere." % city

func _goal_answer(context: Dictionary) -> String:
	var goal := str(context.get("goal","build a stable life")).replace("_"," ")
	if speaking_style == "driven":
		return "My goal is to %s. I don't want to waste the opportunities I get." % goal
	if speaking_style == "warm":
		return "I hope to %s, and I want the people close to me to be happy too." % goal
	return "I'd like to %s. I'm figuring out the best way to get there." % goal

func _apology_answer() -> String:
	if float(traits.get("kindness",0.5)) > 0.62:
		return "It's alright. I appreciate you saying that."
	if float(traits.get("courage",0.5)) > 0.7:
		return "Thank you. Let's make sure it doesn't happen again."
	return "Okay. I hear you."

func _thanks_answer() -> String:
	return "You're welcome. " + ("I'm happy I could help." if float(traits.get("kindness",0.5)) > 0.6 else "No problem.")

func _help_answer() -> String:
	if float(traits.get("kindness",0.5)) > 0.62:
		return "Tell me what's wrong. I'll help if I can."
	return "What do you need? I'll see what I can realistically do."

func _memory_answer(other_id: String) -> String:
	for entry in conversation_memory:
		if str(entry.get("other_id","")) == other_id:
			return "I remember we talked about %s." % str(entry.get("topic","something"))
	return "I don't remember a conversation with you yet, but we can start one now."

func _contains_any(value: String, words: Array) -> bool:
	for word in words:
		if str(word) in value:
			return true
	return false

func _finish(line: String) -> String:
	dialogue_count += 1
	last_utterance = line
	return line


func learn_topic(topic: String, fact: String, confidence: float = 0.5) -> void:
	if topic.is_empty() or fact.is_empty():
		return
	var entries: Array = known_topics.get(topic,[])
	entries.append({"fact":fact,"confidence":clampf(confidence,0.0,1.0),"source":"experience"})
	if entries.size() > 20:
		entries.pop_front()
	known_topics[topic] = entries



func answer_from_knowledge(topic: String) -> String:
	var entries: Array = known_topics.get(topic,[])
	if entries.is_empty():
		return ""
	var best: Dictionary = entries[0]
	for entry in entries:
		if float(entry.get("confidence",0.0)) > float(best.get("confidence",0.0)):
			best = entry
	return str(best.get("fact",""))



func suggest_topic(context: Dictionary = {}) -> String:
	var options: Array[String] = ["work","family","the city","music","food","future plans","technology","weekend","memories","local news"]
	if speaking_style == "curious":
		options.append_array(["new discoveries","science","travel","how things work"])
	elif speaking_style == "warm":
		options.append_array(["friends","how everyone is doing","helping the community"])
	elif speaking_style == "driven":
		options.append_array(["career goals","new opportunities","projects"])
	return options[_rng.randi_range(0,options.size()-1)]



func continue_conversation(topic: String, previous_line: String, context: Dictionary = {}) -> String:
	if previous_line.strip_edges().is_empty():
		return generate_follow_up(topic)
	if _contains_any(previous_line.to_lower(),["sad","hard","difficult","worried"]):
		return "I hear you. What do you think would make the situation a little better?"
	if speaking_style == "curious":
		return "There's another side to %s too. Have you considered it?" % topic
	if speaking_style == "warm":
		return "Thanks for sharing that with me. Is there anything else on your mind?"
	return generate_follow_up(topic,previous_line)



func respond_to_disagreement(other_opinion: String, topic: String) -> String:
	if float(traits.get("kindness",0.5)) > 0.7:
		return "I see it differently, but I respect your view. What led you to that conclusion?"
	if float(traits.get("courage",0.5)) > 0.72:
		return "I disagree with that point. My reasons are different, and I'm happy to explain."
	return "That's not quite how I see it. Maybe we can compare our reasons."



func share_relevant_memory(topic: String) -> String:
	var matches := recall_conversations(topic,2)
	if matches.is_empty():
		return ""
	var memory: Dictionary = matches[0]
	return "That reminds me of our earlier conversation about %s." % str(memory.get("topic",topic))

