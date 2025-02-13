// copyright © tg
// distributed under the terms of the gplv3 license
// https://www.gnu.org/licenses/gpl-3.0.txt

import nttData,bldg,sacobject,sacspell,stats,state,util;
import dlib.math;
import std.algorithm, std.range, std.traits, std.exception, std.conv, std.stdio, std.typecons: Tuple;
import std.random;


void serializeStruct(alias sink,string[] noserialize=[],T)(ref T t)if(is(T==struct)){
	static foreach(member;__traits(allMembers,T)){
		static if(is(typeof(__traits(getMember,t,member).offsetof))){
			static if(!noserialize.canFind(member)){
				serialize!sink(__traits(getMember,t,member));
			}
		}
	}
}
void deserializeStruct(string[] noserialize=[],T,R,B)(ref T result,ObjectState!B state,ref R data){
	static foreach(member;__traits(allMembers,T)){
		static if(is(typeof(__traits(getMember,result,member).offsetof))){
			static if(!noserialize.canFind(member)){
				deserialize(__traits(getMember,result,member),state,data);
			}
		}
	}
}
void serializeClass(alias sink,string[] noserialize=[],T)(T t)if(is(T==class)){
	static foreach(member;__traits(allMembers,T)){
		static if(is(typeof(__traits(getMember,t,member).offsetof))){
			static if(!noserialize.canFind(member)){
				serialize!sink(__traits(getMember,t,member));
			}
		}
	}
}
void deserializeClass(string[] noserialize,T,R,B)(T object,ObjectState!B state,ref R data)if(is(T==class)){
	static foreach(member;__traits(allMembers,T)){
		static if(is(typeof(__traits(getMember,object,member).offsetof))){
			static if(!noserialize.canFind(member)){
				deserialize(__traits(getMember,object,member),state,data);
			}
		}
	}
}

void serialize(alias sink,T)(T t)if(is(T==int)||is(T==uint)||is(T==ulong)||is(T==float)||is(T==bool)||is(T==ubyte)||is(T==char)){
	sink((*cast(ubyte[t.sizeof]*)&t)[]);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==int)||is(T==uint)||is(T==ulong)||is(T==float)||is(T==bool)||is(T==ubyte)||is(T==char)){
	enum n=T.sizeof;
	auto bytes=(cast(ubyte*)(&result))[0..n];
	data.take(n).copy(bytes);
	data.popFrontN(n);
}
void serialize(alias sink,T)(T t)if(is(T==enum)){
	serialize!sink(cast(OriginalType!T)t);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==enum)){
	deserialize(*cast(OriginalType!T*)&result,state,data);
}
void serialize(alias sink)(ref MinstdRand0 rng){ serializeStruct!sink(rng); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==MinstdRand0)){ deserializeStruct(result,state,data); }

void serialize(alias sink,T,size_t n)(ref T[n] values)if(!(is(T==char)||is(T==ubyte)||is(T==int)||is(T==uint)||is(T==ulong)||is(T==float)||is(T==bool)||is(T==ubyte))){
	foreach(ref v;values) serialize!sink(v);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==S[n],S,size_t n)&&!(is(S==char)||is(S==ubyte)||is(S==int)||is(S==uint)||is(S==ulong)||is(S==float)||is(S==bool)||is(S==ubyte))){
	foreach(ref v;result) deserialize(v,state,data);
}

void serialize(alias sink,T,size_t n)(ref T[n] values)if(is(T==char)||is(T==ubyte)||is(T==int)||is(T==uint)||is(T==ulong)||is(T==float)||is(T==bool)||is(T==ubyte)){
	sink(cast(ubyte[])values[]);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==S[n],S,size_t n)&&(is(S==char)||is(S==ubyte)||is(S==int)||is(S==uint)||is(S==ulong)||is(S==float)||is(S==bool)||is(S==ubyte))){
	enum n=T.sizeof;
	auto bytes=(cast(ubyte*)(&result))[0..n];
	data.take(n).copy(bytes);
	data.popFrontN(n);
}
void serialize(alias sink,T)(Array!T values)if(!is(T==bool)){
	static assert(is(size_t:ulong));
	serialize!sink(cast(ulong)values.length);
	foreach(ref v;values.data) serialize!sink(v);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Array!S,S)&&!is(S==bool)){
	ulong len;
	deserialize(len,state,data);
	result.length=cast(size_t)len;
	foreach(ref v;result.data) deserialize(v,state,data);
}
void serialize(alias sink,T)(Array!bool values){
	static assert(0,"TODO?");
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Array!S,S)&&is(S==bool)){
	static assert(0,"TODO?");
}

void serialize(alias sink,T)(T[] values){
	static assert(is(size_t:ulong));
	serialize!sink(cast(ulong)values.length);
	foreach(ref v;values) serialize!sink(cast()v);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==S[],S)){
	ulong len;
	deserialize(len,state,data);
	result.length=cast(size_t)len;
	foreach(ref v;result) deserialize(*cast(Unqual!(typeof(v))*)&v,state,data);
}

void serialize(alias sink,T...)(ref Tuple!T values){ foreach(ref x;values.expand) serialize!sink(x); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Tuple!S,S...)){ foreach(ref x;result.expand) deserialize(x,state,data); }

void serialize(alias sink,T,size_t n)(ref Vector!(T,n) vector){
	static foreach(i;0..n) serialize!sink(vector[i]);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Vector!(S,n),S,size_t n)){
	enum _=is(T==Vector!(S,n),S,size_t n);
	static foreach(i;0..n) deserialize(result[i],state,data);
}

void serialize(alias sink)(ref Quaternionf rotation){ foreach(ref x;rotation.tupleof) serialize!sink(x); }
void deserialize(T,R,B)(ref T rotation,ObjectState!B state,ref R data)if(is(T==Quaternionf)){
	foreach(ref x;rotation.tupleof) deserialize(x,state,data);
}

void serialize(alias sink,T,size_t n)(SmallArray!(T,n) values)if(!is(T==bool)){ return serializeStruct!sink(values); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SmallArray!(S,n),S,size_t n)){
	deserializeStruct(result,state,data);
}

void serialize(alias sink,T)(ref Queue!T queue){ serializeStruct!sink(queue); } // TODO: compactify?
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Queue!S,S)){
	deserializeStruct(result,state,data);
}

void serialize(alias sink,B)(SacObject!B obj){ serialize!sink(obj?obj.nttTag:cast(char[4])"\0\0\0\0"); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacObject!B)){
	char[4] tag;
	deserialize(tag,state,data);
	if(tag!="\0\0\0\0") result=T.get(tag);
	else result=null;
}

void serialize(alias sink)(ref OrderTarget orderTarget){ serializeStruct!sink(orderTarget); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==OrderTarget)){
	deserializeStruct(result,state,data);
}

void serialize(alias sink)(ref Order order){ serializeStruct!sink(order); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Order)){
	deserializeStruct(result,state,data);
}

void serialize(alias sink)(ref PositionPredictor locationPredictor){ serializeStruct!sink(locationPredictor); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==PositionPredictor)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Path path){ serializeStruct!sink(path); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Path)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref CreatureAI creatureAI){ serializeStruct!sink(creatureAI); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CreatureAI)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref CreatureState creatureState){ serializeStruct!sink(creatureState); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CreatureState)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref stats.Effects effects){ serializeStruct!sink(effects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==stats.Effects)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref CreatureStats creatureStats){ serializeStruct!sink(creatureStats); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CreatureStats)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B,RenderMode mode)(ref MovingObjects!(B,mode) objects){ serializeStruct!sink(objects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==MovingObjects!(B,mode),RenderMode mode)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B,RenderMode mode)(ref StaticObjects!(B,mode) objects){ serializeStruct!sink(objects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==StaticObjects!(B,mode),RenderMode mode)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Soul!B soul){ serializeStruct!sink(soul); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Soul!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Souls!B souls){ serializeStruct!sink(souls); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Souls!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(immutable(Bldg)* bldg){ auto tag=cast(char[4])bldgTags[bldg]; serialize!sink(tag); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==immutable(Bldg)*)){ char[4] tag; deserialize(tag,state,data); result=&bldgs[tag]; }

void serialize(alias sink,B)(ref Building!B building){ serializeStruct!sink(building); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Building!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Buildings!B buildings){ serializeStruct!sink(buildings); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Buildings!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(SacSpell!B spell){ serialize!sink(spell?spell.tag:cast(char[4])"\0\0\0\0"); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacSpell!B)){
	char[4] tag;
	deserialize(tag,state,data);
	if(tag!="\0\0\0\0") result=T.get(tag);
	else result=null;
}

void serialize(alias sink,B)(ref SpellInfo!B spell){ serializeStruct!sink(spell); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SpellInfo!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Spellbook!B spellbook){ serializeStruct!sink(spellbook); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Spellbook!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref WizardInfo!B wizard){ serializeStruct!sink(wizard); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==WizardInfo!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref WizardInfos!B wizards){ serializeStruct!sink(wizards); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==WizardInfos!B)){ deserializeStruct(result,state,data); }


void serialize(alias sink,B)(SacParticle!B particle)in{
	assert(!!particle);
}do{
	serialize!sink(particle.type);
	serialize!sink(particle.side);
}
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacParticle!B)){
	ParticleType type;
	deserialize(type,state,data);
	int side;
	deserialize(side,state,data);
	if(side!=-1){
		switch(type){
			case ParticleType.manalith: result=state.sides.manaParticle(side); break;
			case ParticleType.shrine: result=state.sides.shrineParticle(side); break;
			case ParticleType.manahoar: result=state.sides.manahoarParticle(side); break;
			default: enforce(0,text("invalid particle type ",type," with side ",side)); assert(0);
		}
	}else result=T.get(type);
}

void serialize(alias sink,B,bool relative,bool sideFiltered)(ref Particles!(B,relative,sideFiltered) particles){ serializeStruct!sink(particles); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Particles!(B,relative,sideFiltered),bool relative,bool sideFiltered)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Debris!B debris){ serializeStruct!sink(debris); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Debris!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Explosion!B explosion){ serializeStruct!sink(explosion); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Explosion!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Fire!B fire){ serializeStruct!sink(fire); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Fire!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ManaDrain!B manaDrain){ serializeStruct!sink(manaDrain); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ManaDrain!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref BuildingDestruction buildingDestruction){ serializeStruct!sink(buildingDestruction); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BuildingDestruction)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref GhostKill ghostKill){ serializeStruct!sink(ghostKill); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GhostKill)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref CreatureCasting!B creatureCast){ serializeStruct!sink(creatureCast); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CreatureCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref StructureCasting!B structureCast){ serializeStruct!sink(structureCast); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==StructureCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref BlueRing!B blueRing){ serializeStruct!sink(blueRing); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BlueRing!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref RedVortex vortex){ serializeStruct!sink(vortex); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RedVortex)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SacDocCasting!B convertCasting){ serializeStruct!sink(convertCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacDocCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref SacDocTether sacDocTether){ serializeStruct!sink(sacDocTether); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacDocTether)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SacDocCarry!B sacDocCarry){ serializeStruct!sink(sacDocCarry); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SacDocCarry!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Ritual!B ritual){ serializeStruct!sink(ritual); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Ritual!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref TeleportCasting!B teleportCasting){ serializeStruct!sink(teleportCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TeleportCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref TeleportEffect!B teleportEffect){ serializeStruct!sink(teleportEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TeleportEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref TeleportRing!B teleportRing){ serializeStruct!sink(teleportRing); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TeleportRing!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref GuardianCasting!B guardianCasting){ serializeStruct!sink(guardianCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GuardianCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Guardian guardian){ serializeStruct!sink(guardian); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Guardian)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SpeedUp!B speedUp){ serializeStruct!sink(speedUp); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SpeedUp!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SpeedUpShadow!B speedUpShadow){ serializeStruct!sink(speedUpShadow); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SpeedUpShadow!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref HealCasting!B healCasting){ serializeStruct!sink(healCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==HealCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Heal!B heal){ serializeStruct!sink(heal); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Heal!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref LightningCasting!B lightningCasting){ serializeStruct!sink(lightningCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==LightningCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref LightningBolt lightningBolt){ serializeStruct!sink(lightningBolt); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==LightningBolt)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Lightning!B lightning){ serializeStruct!sink(lightning); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Lightning!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref WrathCasting!B wrathCasting){ serializeStruct!sink(wrathCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==WrathCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Wrath!B wrath){ serializeStruct!sink(wrath); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Wrath!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FireballCasting!B fireballCasting){ serializeStruct!sink(fireballCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FireballCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Fireball!B fireball){ serializeStruct!sink(fireball); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Fireball!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RockCasting!B rockCasting){ serializeStruct!sink(rockCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RockCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Rock!B rock){ serializeStruct!sink(rock); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Rock!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SwarmCasting!B swarmCasting){ serializeStruct!sink(swarmCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SwarmCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Bug!B bug){ serializeStruct!sink(bug); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Bug!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Swarm!B swarm){ serializeStruct!sink(swarm); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Swarm!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SkinOfStoneCasting!B skinOfStoneCasting){ serializeStruct!sink(skinOfStoneCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SkinOfStoneCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SkinOfStone!B skinOfStone){ serializeStruct!sink(skinOfStone); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SkinOfStone!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref EtherealFormCasting!B etherealFormCasting){ serializeStruct!sink(etherealFormCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==EtherealFormCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref EtherealForm!B etherealForm){ serializeStruct!sink(etherealForm); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==EtherealForm!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FireformCasting!B fireformCasting){ serializeStruct!sink(fireformCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FireformCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Fireform!B fireform){ serializeStruct!sink(fireform); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Fireform!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ProtectiveSwarmCasting!B protectiveSwarmCasting){ serializeStruct!sink(protectiveSwarmCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ProtectiveSwarmCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ProtectiveBug!B protectiveBug){ serializeStruct!sink(protectiveBug); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ProtectiveBug!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ProtectiveSwarm!B protectiveSwarm){ serializeStruct!sink(protectiveSwarm); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ProtectiveSwarm!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AirShieldCasting!B airShieldCasting){ serializeStruct!sink(airShieldCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AirShieldCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AirShield!B.Particle particle){ serializeStruct!sink(particle); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AirShield!B.Particle)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AirShield!B airShield){ serializeStruct!sink(airShield); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AirShield!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FreezeCasting!B freezeCasting){ serializeStruct!sink(freezeCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FreezeCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Freeze!B freeze){ serializeStruct!sink(freeze); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Freeze!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RingsOfFireCasting!B ringsOfFireCasting){ serializeStruct!sink(ringsOfFireCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RingsOfFireCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RingsOfFire!B ringsOfFire){ serializeStruct!sink(ringsOfFire); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RingsOfFire!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SlimeCasting!B slimeCasting){ serializeStruct!sink(slimeCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SlimeCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Slime!B slime){ serializeStruct!sink(slime); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Slime!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref GraspingVinesCasting!B graspingVinesCasting){ serializeStruct!sink(graspingVinesCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GraspingVinesCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Vine vine){ serializeStruct!sink(vine); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Vine)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref GraspingVines!B graspingVines){ serializeStruct!sink(graspingVines); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GraspingVines!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SoulMoleCasting!B soulMoleCasting){ serializeStruct!sink(soulMoleCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SoulMoleCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SoulMole!B soulMole){ serializeStruct!sink(soulMole); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SoulMole!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RainbowCasting!B rainbowCasting){ serializeStruct!sink(rainbowCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RainbowCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Rainbow!B rainbow){ serializeStruct!sink(rainbow); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Rainbow!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RainbowEffect!B rainbowEffect){ serializeStruct!sink(rainbowEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RainbowEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ChainLightningCasting!B chainLightningCasting){ serializeStruct!sink(chainLightningCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ChainLightningCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ChainLightningCastingEffect!B chainLightningCastingEffect){ serializeStruct!sink(chainLightningCastingEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ChainLightningCastingEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ChainLightning!B chainLightning){ serializeStruct!sink(chainLightning); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ChainLightning!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AnimateDeadCasting!B animateDeadCasting){ serializeStruct!sink(animateDeadCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AnimateDeadCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AnimateDead!B animateDead){ serializeStruct!sink(animateDead); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AnimateDead!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref AnimateDeadEffect!B animateDeadEffect){ serializeStruct!sink(animateDeadEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AnimateDeadEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref EruptCasting!B eruptCasting){ serializeStruct!sink(eruptCasting); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==EruptCasting!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Erupt!B erupt){ serializeStruct!sink(erupt); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Erupt!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref EruptDebris!B eruptDebris){ serializeStruct!sink(eruptDebris); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==EruptDebris!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref BrainiacProjectile!B brainiacProjectile){ serializeStruct!sink(brainiacProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BrainiacProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref BrainiacEffect brainiacEffect){ serializeStruct!sink(brainiacEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BrainiacEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ShrikeProjectile!B shrikeProjectile){ serializeStruct!sink(shrikeProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ShrikeProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref ShrikeEffect shrikeEffect){ serializeStruct!sink(shrikeEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ShrikeEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref LocustProjectile!B locustProjectile){ serializeStruct!sink(locustProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==LocustProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SpitfireProjectile!B spitfireProjectile){ serializeStruct!sink(spitfireProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SpitfireProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref SpitfireEffect spitfireEffect){ serializeStruct!sink(spitfireEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SpitfireEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref GargoyleProjectile!B gargoyleProjectile){ serializeStruct!sink(gargoyleProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GargoyleProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref GargoyleEffect gargoyleEffect){ serializeStruct!sink(gargoyleEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GargoyleEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref EarthflingProjectile!B earthflingProjectile){ serializeStruct!sink(earthflingProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==EarthflingProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FlameMinionProjectile!B flameMinionProjectile){ serializeStruct!sink(flameMinionProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FlameMinionProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FallenProjectile!B fallenProjectile){ serializeStruct!sink(fallenProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FallenProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SylphEffect!B sylphEffect){ serializeStruct!sink(sylphEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SylphEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SylphProjectile!B sylphProjectile){ serializeStruct!sink(sylphProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SylphProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RangerEffect!B rangerEffect){ serializeStruct!sink(rangerEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RangerEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RangerProjectile!B rangerProjectile){ serializeStruct!sink(rangerProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RangerProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref NecrylProjectile!B necrylProjectile){ serializeStruct!sink(necrylProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==NecrylProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Poison poison){ serializeStruct!sink(poison); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Poison)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ScarabProjectile!B scarabProjectile){ serializeStruct!sink(scarabProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ScarabProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref BasiliskProjectile!B basiliskProjectile){ serializeStruct!sink(basiliskProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BasiliskProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref BasiliskEffect basiliskEffect){ serializeStruct!sink(basiliskEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BasiliskEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Petrification petrification){ serializeStruct!sink(petrification); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Petrification)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref TickfernoProjectile!B tickfernoProjectile){ serializeStruct!sink(tickfernoProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TickfernoProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref TickfernoEffect tickfernoEffect){ serializeStruct!sink(tickfernoEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TickfernoEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref VortickProjectile!B vortickProjectile){ serializeStruct!sink(vortickProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==VortickProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref VortickEffect vortickEffect){ serializeStruct!sink(vortickEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==VortickEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref VortexEffect!B vortexEffect){ serializeStruct!sink(vortexEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==VortexEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref VortexEffect!B.Particle particle){ serializeStruct!sink(particle); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==VortexEffect!B.Particle)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SquallProjectile!B squallProjectile){ serializeStruct!sink(squallProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SquallProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref SquallEffect squallEffect){ serializeStruct!sink(squallEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SquallEffect)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Pushback!B pushback){ serializeStruct!sink(pushback); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Pushback!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref FlummoxProjectile!B flummoxProjectile){ serializeStruct!sink(flummoxProjectile); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==FlummoxProjectile!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref PyromaniacRocket!B pyromaniacRocket){ serializeStruct!sink(pyromaniacRocket); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==PyromaniacRocket!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref GnomeEffect!B gnomeEffect){ serializeStruct!sink(gnomeEffect); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==GnomeEffect!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref PoisonDart!B poisonDart){ serializeStruct!sink(poisonDart); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==PoisonDart!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref RockForm!B rockForm){ serializeStruct!sink(rockForm); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==RockForm!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Stealth!B stealth){ serializeStruct!sink(stealth); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Stealth!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref LifeShield!B lifeShield){ serializeStruct!sink(lifeShield); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==LifeShield!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref DivineSight!B divineSight){ serializeStruct!sink(divineSight); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==DivineSight!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SteamCloud!B steamCloud){ serializeStruct!sink(steamCloud); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SteamCloud!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref PoisonCloud!B poisonCloud){ serializeStruct!sink(poisonCloud); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==PoisonCloud!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref BlightMite!B blightMite){ serializeStruct!sink(blightMite); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==BlightMite!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref LightningCharge!B lightningCharge){ serializeStruct!sink(lightningCharge); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==LightningCharge!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref Protector!B protector){ serializeStruct!sink(protector); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Protector!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Appearance appearance){ serializeStruct!sink(appearance); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Appearance)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref Disappearance disappearance){ serializeStruct!sink(disappearance); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Disappearance)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref AltarDestruction altarDestruction){ serializeStruct!sink(altarDestruction); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==AltarDestruction)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref ScreenShake screenShake){ serializeStruct!sink(screenShake); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ScreenShake)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref TestDisplacement testDisplacement){ serializeStruct!sink(testDisplacement); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==TestDisplacement)){ deserializeStruct(result,state,data); }

private alias Effects=state.Effects;
void serialize(alias sink,B)(ref Effects!B effects){ serializeStruct!sink(effects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Effects!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref CommandCone!B commandCone){ serializeStruct!sink(commandCone); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CommandCone!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref CommandCones!B.CommandConeElement commandConeElement){ serializeStruct!sink(commandConeElement); }
// void deserialize(T,R)(ref T result,ref R data)if(is(T==CommandCone!B.CommandConeElement,B)){ deserializeStruct(result,data); } // DMD bug
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(T.stringof=="CommandConeElement"){ deserializeStruct(result,state,data); } // DMD bug

void serialize(alias sink,B)(ref CommandCones!B commandCones){ serializeStruct!sink(commandCones); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CommandCones!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B,RenderMode mode)(ref Objects!(B,mode) objects){ serializeStruct!(sink,["fixedObjects"])(objects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Objects!(B,mode),RenderMode mode)){ deserializeStruct!(["fixedObjects"])(result,state,data); }

void serialize(alias sink)(ref Id id){ serializeStruct!sink(id); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Id)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref ObjectManager!B objects){ serializeStruct!sink(objects); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==ObjectManager!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink)(ref CreatureGroup creatures){ serializeStruct!sink(creatures); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==CreatureGroup)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SideData!B side){ serializeStruct!sink(side); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SideData!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ref SideManager!B sides){ serializeStruct!sink(sides); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==SideManager!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(ObjectState!B state){
	enum noserialize=["map","sides","proximity","pathFinder","toRemove"];
	if(state.proximity.active) stderr.writeln("warning: serialize: proximity active");
	if(state.toRemove.length!=0) stderr.writeln("warning: serialize: toRemove not empty");
	serializeClass!(sink,noserialize)(state);
}
void deserialize(T,R)(T state,ref R data)if(is(T==ObjectState!B,B)){
	enum noserialize=["map","sides","proximity","pathFinder","toRemove"];
	if(state.proximity.active) stderr.writeln("warning: deserialize: proximity active");
	if(state.toRemove.length!=0) stderr.writeln("warning: deserialize: toRemove not empty");
	deserializeClass!noserialize(state,state,data);
}

void serialize(alias sink)(ref Target target){ serializeStruct!sink(target); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Target)){ deserializeStruct(result,state,data); }
void serialize(alias sink,B)(ref Command!B command){ serializeStruct!sink(command); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Command!B)){ deserializeStruct(result,state,data); }

import sids;
void serialize(alias sink)(ref Side side){ serializeStruct!sink(side); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Side)){ deserializeStruct(result,state,data); }

import recording_;

void serialize(alias sink,B)(Event!B event){ serializeStruct!sink(event); }
void deserialize(T,R,B)(ref T result,ObjectState!B state,ref R data)if(is(T==Event!B)){ deserializeStruct(result,state,data); }

void serialize(alias sink,B)(Recording!B recording)in{
	assert(recording.finalized);
}do{
	serialize!sink(recording.mapName);
	serializeClass!(sink,["manaParticles","shrineParticles","manahoarParticles"])(recording.sides);
	serialize!sink(recording.committed);
	serialize!sink(recording.commands);
	serialize!sink(recording.events);
}
void deserialize(T,R)(T recording,ref R data)if(is(T==Recording!B,B)){
	enum _=is(T==Recording!B,B);
	deserialize(recording.mapName,ObjectState!B.init,data);
	import sacmap, ntts;
	auto hmap=getHmap(recording.mapName);
	auto map=new SacMap!B(hmap);
	auto nttData=loadNTTs(hmap[0..$-".HMAP".length]~".NTTS");
	auto sides=new Sides!B();
	deserializeClass!(["manaParticles","shrineParticles","manahoarParticles"])(sides,ObjectState!B.init,data);
	auto proximity=new Proximity!B();
	auto pathFinder=new PathFinder!B(map);
	ulong len;
	deserialize(len,ObjectState!B.init,data);
	enforce(len!=0);
	foreach(i;0..len){
		auto state=new ObjectState!B(map,sides,proximity,pathFinder);
		foreach(w;nttData.widgetss){ // TODO: get rid of code duplication
			auto curObj=SacObject!B.getWIDG(w.tag);
			foreach(pos;w.positions){
				auto position=Vector3f(pos[0],pos[1],0);
				if(!state.isOnGround(position)) continue;
				position.z=state.getGroundHeight(position);
				auto rotation=facingQuaternion(-pos[2]);
				state.addFixed(FixedObject!B(curObj,position,rotation));
			}
		}
		deserialize(state,data);
		recording.committed~=state;
	}
	deserialize(recording.commands,ObjectState!B.init,data);
	deserialize(recording.events,ObjectState!B.init,data);
}
