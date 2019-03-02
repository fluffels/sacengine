import options;
import dagonBackend;
import sids, ntts, sacobject, sacmap, state;
import util;
import dlib.math;
import std.string, std.array, std.range, std.algorithm, std.stdio;
import std.exception, std.conv, std.typecons;

int main(string[] args){
	import derelict.openal.al;
	DerelictAL.load();
	import derelict.mpg123;
	DerelictMPG123.load();
	import core.memory;
	GC.disable(); // TODO: figure out where GC memory is used incorrectly
	if(args.length==1) args~="extracted/jamesmod/JMOD.WAD!/modl.FLDR/jman.MRMC/jman.MRMM";
	auto opts=args[1..$].filter!(x=>x.startsWith("--")).array;
	args=chain(args[0..1],args[1..$].filter!(x=>!x.startsWith("--"))).array;
	Options options={
		//shadowMapResolution: 8192,
		//shadowMapResolution: 4096,
		//shadowMapResolution: 2048,
		shadowMapResolution: 1024,
		enableWidgets: true,
	};
	static Tuple!(int,"width",int,"height") parseResolution(string s){
		auto t=s.split('x');
		if(t.length==2) return tuple!("width","height")(to!int(t[0]),to!int(t[1]));
		return tuple!("width","height")(16*to!int(s)/9,to!int(s));
	}
	foreach(opt;opts){
		if(opt.startsWith("--resolution")){
			auto resolution=parseResolution(opt["--resolution=".length..$]);
			options.width=resolution.width;
			options.height=resolution.height;
		}else if(opt.startsWith("--aspect-distortion=")){
			options.aspectDistortion=to!float(opt["--aspect-distortion=".length..$]);
		}else if(opt.startsWith("--shadow-map-resolution=")){
			options.shadowMapResolution=to!int(opt["--shadow-map-resolution=".length..$]);
		}else if(opt.startsWith("--glow-brightness=")){
			options.glowBrightness=to!float(opt["--glow-brightness=".length..$]);
		}else if(opt.startsWith("--replicate-creatures=")){
			options.replicateCreatures=to!int(opt["--replicate-creatures=".length..$]);
		}else if(opt.startsWith("--cursor-size=")){
			options.cursorSize=to!int(opt["--cursor-size=".length..$]);
		}else if(opt.startsWith("--wizard=")){
			options.wizard=opt["--wizard=".length..$];
		}else LoptSwitch: switch(opt){
			static string getOptionName(string memberName){
				import std.ascii;
				auto m=memberName;
				if(m.startsWith("enable")) m=m["enable".length..$];
				else if(m.startsWith("disable")) m=m["disable".length..$];
				string r;
				foreach(char c;m){
					if(isUpper(c)) r~="-"~toLower(c);
					else r~=c;
				}
				if(r[0]=='-') r=r[1..$];
				return r;
			}
			static foreach(member;__traits(allMembers,Options)){
				static if(is(typeof(__traits(getMember,options,member))==bool)){
					case "--disable-"~getOptionName(member):
						__traits(getMember,options,member)=false;
						break LoptSwitch;
					case "--enable-"~getOptionName(member):
						__traits(getMember,options,member)=true;
						break LoptSwitch;
				}
			}
			default:
				stderr.writeln("unknown option: ",opt);
				return 1;
		}
	}
	auto backend=DagonBackend(options);
	GameState!DagonBackend state;
	foreach(ref i;1..args.length){
		string anim="";
		if(i+1<args.length&&args[i+1].endsWith(".SXSK"))
			anim=args[i+1];
		if(args[i].endsWith(".HMAP")){
			enforce(!state);
			auto map=new SacMap!DagonBackend(args[i]);
			auto sids=loadSids(args[i][0..$-".HMAP".length]~".SIDS");
			auto ntts=loadNTTs(args[i][0..$-".HMAP".length]~".NTTS");
			state=new GameState!DagonBackend(map,sids,ntts,options);
			backend.setState(state);
			bool flag=false;
			state.current.eachBuilding!((bldg,state,scene,flag,options){
				if(*flag) return;
				if(bldg.side==backend.scene.renderSide && bldg.isAltar){
					*flag=true;
					alias B=DagonBackend;
					auto altar=state.staticObjectById!((obj)=>obj, function StaticObject!B(){ assert(0); })(bldg.componentIds[0]);
					auto curObj=SacObject!B.getSAXS!Wizard(options.wizard.retro.to!string[0..4]);
					import std.math: PI;
					int closestManafount=0;
					Vector3f manafountPosition;
					state.eachBuilding!((bldg,altarPos,closest,manaPos,state){
						if(!bldg.isManafount) return;
						auto pos=bldg.position(state);
						if(*closest==0||(altarPos.xy-pos.xy).length<(altarPos.xy-manaPos.xy).length){
							*closest=bldg.id;
							*manaPos=pos;
						}
					})(altar.position,&closestManafount,&manafountPosition,state);
					int orientation=0;
					enum distance=15.0f;
					auto facingOffset=bldg.isStratosAltar?PI/4.0f:0.0f;
					auto facing=bldg.facing+facingOffset;
					auto rotation=facingQuaternion(facing);
					auto position=altar.position+rotate(rotation,Vector3f(0.0f,distance,0.0f));
					foreach(i;1..4){
						auto facingCand=bldg.facing+facingOffset+i*PI/2;
						auto rotationCand=facingQuaternion(facingCand);
						auto positionCand=altar.position+rotate(rotationCand,Vector3f(0.0f,distance,0.0f));
						if((positionCand-manafountPosition).xy.length<(position-manafountPosition).xy.length){
							facing=facingCand;
							rotation=rotationCand;
							position=positionCand;
						}
					}
					bool onGround=state.isOnGround(position);
					if(onGround)
						position.z=state.getGroundHeight(position);
					auto mode=CreatureMode.idle;
					auto movement=CreatureMovement.onGround;
					if(movement==CreatureMovement.onGround && !onGround)
						movement=curObj.canFly?CreatureMovement.flying:CreatureMovement.tumbling;
					auto creatureState=CreatureState(mode, movement, facing);
					import animations;
					auto obj=MovingObject!B(curObj,position,rotation,AnimationState.stance1,0,creatureState,curObj.creatureStats(0),scene.renderSide);
					obj.setCreatureState(state);
					obj.updateCreaturePosition(state);
					auto id=state.addObject(obj);
					scene.focusCamera(id);
				}
			})(state.current,backend.scene,&flag,options);
		}else{
			auto sac=new SacObject!DagonBackend(args[i],float.nan,anim);
			auto position=Vector3f(1270.0f, 1270.0f, 0.0f);
			if(state && state.current.isOnGround(position))
				position.z=state.current.getGroundHeight(position);
			backend.addObject(sac,position,facingQuaternion(0));
		}
		if(i+1<args.length&&args[i+1].endsWith(".SXSK"))
			i+=1;
	}
	backend.run();
	return 0;
}
