import std.algorithm, std.range;
import std.container.array: Array;
import std.exception, std.stdio, std.conv;
import dlib.math, std.math;
import std.typecons;
import ntts, nttData;
import sacmap, sacobject, animations;
import util,options;
enum int updateFPS=60;
static assert(updateFPS%animFPS==0);
enum updateAnimFactor=updateFPS/animFPS;

enum RenderMode{
	opaque,
	transparent,
}

struct Id{
	RenderMode mode;
	int type;
	int index=-1;
}

enum CreatureMode{
	idle,
	moving,
	dying,
	dead,
	takeoff,
	landing,
	meleeAttacking,
}

enum CreatureMovement{
	onGround,
	flying,
	tumbling,
}

enum MovementDirection{
	none,
	forward,
	backward,
}

enum RotationDirection{
	none,
	left,
	right,
}

struct CreatureState{
	auto mode=CreatureMode.idle;
	auto movement=CreatureMovement.onGround;
	float facing=0.0f, flyingDisplacement=0.0f;
	auto movementDirection=MovementDirection.none;
	auto rotationDirection=RotationDirection.none;
	auto fallingSpeed=Vector3f(0.0f,0.0f,0.0f);
}

struct MovingObject(B){
	SacObject!B sacObject;
	Vector3f position;
	Quaternionf rotation;
	AnimationState animationState;
	int frame;
	CreatureState creatureState;

	this(SacObject!B sacObject,Vector3f position,Quaternionf rotation,AnimationState animationState,int frame,CreatureState creatureState){
		this.sacObject=sacObject;
		this.position=position;
		this.rotation=rotation;
		this.animationState=animationState;
		this.frame=frame;
		this.creatureState=creatureState;
	}
}


struct StaticObject(B){
	SacObject!B sacObject;
	Vector3f position;
	Quaternionf rotation;

	this(SacObject!B sacObject,Vector3f position,Quaternionf rotation){
		this.sacObject=sacObject;
		this.position=position;
		this.rotation=rotation;
	}
}

struct FixedObject(B){
	SacObject!B sacObject;
	Vector3f position;
	Quaternionf rotation;

	this(SacObject!B sacObject,Vector3f position,Quaternionf rotation){
		this.sacObject=sacObject;
		this.position=position;
		this.rotation=rotation;
	}
}

void assignArray(T)(ref Array!T to, ref Array!T from){
	to.length=from.length;
	foreach(i;0..from.length){ // TODO: this is slow!
		static if(is(T:Array!S,S))
			assignArray(to[i],from[i]);
		else to[i]=from[i];
	}
}

struct MovingObjects(B,RenderMode mode){
	enum renderMode=mode;
	SacObject!B sacObject;
	Array!int ids;
	Array!Vector3f positions;
	Array!Quaternionf rotations;
	Array!AnimationState animationStates;
	Array!int frames;
	Array!CreatureState creatureStates;
	@property int length(){ assert(ids.length<=int.max); return cast(int)ids.length; }

	void reserve(int reserveSize){
		ids.reserve(reserveSize);
		positions.reserve(reserveSize);
		rotations.reserve(reserveSize);
		animationStates.reserve(reserveSize);
		frames.reserve(reserveSize);
		creatureStates.reserve(reserveSize);
	}

	void addObject(int id,MovingObject!B object){
		ids~=id;
		positions~=object.position;
		rotations~=object.rotation;
		animationStates~=object.animationState;
		frames~=object.frame;
		creatureStates~=object.creatureState;
	}
	void opAssign(ref MovingObjects!(B,mode) rhs){
		assert(sacObject is null || sacObject is rhs.sacObject);
		sacObject = rhs.sacObject;
		assignArray(ids,rhs.ids);
		assignArray(positions,rhs.positions);
		assignArray(rotations,rhs.rotations);
		assignArray(animationStates,rhs.animationStates);
		assignArray(frames,rhs.frames);
		assignArray(creatureStates,rhs.creatureStates);
	}
	MovingObject!B opIndex(int i){
		return MovingObject!B(sacObject,positions[i],rotations[i],animationStates[i],frames[i],creatureStates[i]);
	}
	void opIndexAssign(MovingObject!B obj,int i){
		assert(obj.sacObject is sacObject);
		positions[i]=obj.position;
		rotations[i]=obj.rotation;
		animationStates[i]=obj.animationState;
		frames[i]=obj.frame;
		creatureStates[i]=obj.creatureState;
	}
}
auto each(alias f,B,RenderMode mode,T...)(ref MovingObjects!(B,mode) movingObjects,T args){
	foreach(i;0..movingObjects.length){
		static if(!is(typeof(f(movingObjects[i],args)))){
			// TODO: find a better way to check whether argument taken by reference
			auto obj=movingObjects[i];
			f(obj,args);
			movingObjects[i]=obj;
		}else f(movingObjects[i],args);
	}
}


struct StaticObjects(B){
	enum renderMode=RenderMode.opaque;
	SacObject!B sacObject;
	Array!int ids;
	Array!Vector3f positions;
	Array!Quaternionf rotations;

	@property int length(){ assert(ids.length<=int.max); return cast(int)ids.length; }
	void addObject(int id,StaticObject!B object){
		ids~=id;
		positions~=object.position;
		rotations~=object.rotation;
	}
	void opAssign(ref StaticObjects!B rhs){
		assert(sacObject is null || sacObject is rhs.sacObject);
		sacObject=rhs.sacObject;
		assignArray(ids,rhs.ids);
		assignArray(positions,rhs.positions);
		assignArray(rotations,rhs.rotations);
	}
	StaticObject!B opIndex(int i){
		return StaticObject!B(sacObject,positions[i],rotations[i]);
	}
	void opIndexAssign(StaticObject!B obj,int i){
		positions[i]=obj.position;
		rotations[i]=obj.rotation;
	}
}
auto each(alias f,B,T...)(ref StaticObjects!B staticObjects,T args){
	foreach(i;0..staticObjects.length)
		f(staticObjects[i],args);
}

struct FixedObjects(B){
	enum renderMode=RenderMode.opaque;
	SacObject!B sacObject;
	Array!Vector3f positions;
	Array!Quaternionf rotations;
	@property int length(){ assert(positions.length<=int.max); return cast(int)positions.length; }

	void addFixed(FixedObject!B object)in{
		assert(sacObject==object.sacObject);
	}body{
		positions~=object.position;
		rotations~=object.rotation;
	}
	void opAssign(ref FixedObjects!B rhs){
		assert(sacObject is null || sacObject is rhs.sacObject);
		sacObject=rhs.sacObject;
		assignArray(positions,rhs.positions);
		assignArray(rotations,rhs.rotations);
	}
	FixedObject!B opIndex(int i){
		return FixedObject!B(sacObject,positions[i],rotations[i]);
	}
	void opIndexAssign(StaticObject!B obj,int i){
		positions[i]=obj.position;
		rotations[i]=obj.rotation;
	}
}
auto each(alias f,B,T...)(ref FixedObjects!B fixedObjects,T args){
	foreach(i;0..length)
		f(fixedObjects[i],args);
}


struct Objects(B,RenderMode mode){
	Array!(MovingObjects!(B,mode)) movingObjects;
	static if(mode == RenderMode.opaque){
		Array!(StaticObjects!B) staticObjects;
		FixedObjects!B[] fixedObjects;
	}
	static if(mode==RenderMode.opaque){
		Id addObject(T)(int id,T object) if(is(T==MovingObject!B)||is(T==StaticObject!B)){
			Id result;
			auto type=object.sacObject.stateIndex; // TODO: support RenderMode.transparent
			if(type==-1){
				static if(is(T==MovingObject!B)){
					type=object.sacObject.stateIndex=cast(int)movingObjects.length;
					movingObjects.length=movingObjects.length+1;
					movingObjects[$-1].sacObject=object.sacObject;
				}else{
					type=object.sacObject.stateIndex=cast(int)staticObjects.length+numMoving;
					staticObjects.length=staticObjects.length+1;
					staticObjects[$-1].sacObject=object.sacObject;
				}
			}
			static if(is(T==MovingObject!B)){
				enforce(type<numMoving);
				result=Id(mode,type,movingObjects[type].length);
				movingObjects[type].addObject(id,object);
			}else{
				enforce(numMoving<=type && type<numMoving+numStatic);
				result=Id(mode,type,staticObjects[type-numMoving].length);
				staticObjects[type-numMoving].addObject(id,object);
			}
			return result;
		}
		void addFixed(FixedObject!B object){
			auto type=object.sacObject.stateIndex;
			if(type==-1){
				type=object.sacObject.stateIndex=cast(int)fixedObjects.length+numMoving+numStatic;
				fixedObjects.length=fixedObjects.length+1;
				fixedObjects[$-1].sacObject=object.sacObject;
			}
			enforce(numMoving+numStatic<=type);
			fixedObjects[type-(numMoving+numStatic)].addFixed(object);
		}
	}
	void opAssign(Objects!(B,mode) rhs){
		assignArray(movingObjects,rhs.movingObjects);
		static if(mode == RenderMode.opaque){
			assignArray(staticObjects,rhs.staticObjects);
			fixedObjects=rhs.fixedObjects; // by reference
		}
	}
}
auto each(alias f,B,RenderMode mode,T...)(ref Objects!(B,mode) objects,T args){
	with(objects){
		foreach(ref movingObject;movingObjects)
			movingObject.each!f(args);
		static if(mode == RenderMode.opaque){
			foreach(ref staticObject;staticObjects)
				staticObject.each!f(args);
			foreach(ref fixedObject;fixedObjects)
				fixedObject.each!f(args);
		}
	}
}
auto eachMoving(alias f,B,RenderMode mode,T...)(ref Objects!(B,mode) objects,T args){
	with(objects){
		foreach(ref movingObject;movingObjects)
			movingObject.each!f(args);
	}
}

auto eachByType(alias f,B,RenderMode mode,T...)(ref Objects!(B,mode) objects,T args){
	with(objects){
		foreach(ref movingObject;movingObjects)
			f(movingObject,args);
		static if(mode == RenderMode.opaque){
			foreach(ref staticObject;staticObjects)
				f(staticObject,args);
			foreach(ref fixedObject;fixedObjects)
				f(fixedObject,args);
		}
	}
}

enum numMoving=100;
enum numStatic=300;

struct ObjectManager(B){
	Array!Id ids;
	Objects!(B,RenderMode.opaque) opaqueObjects;
	Objects!(B,RenderMode.transparent) transparentObjects;
	int addObject(T)(T object) if(is(T==MovingObject!B)||is(T==StaticObject!B)){
		if(ids.length>=int.max) return 0;
		int id=cast(int)ids.length+1;
		ids~=opaqueObjects.addObject(id,object);
		return id;
	}
	void addTransparent(T)(T object, float alpha){
		assert(0,"TODO");
	}
	void addFixed(FixedObject!B object){
		opaqueObjects.addFixed(object);
	}

	void opAssign(ObjectManager!B rhs){
		assignArray(ids,rhs.ids);
		opaqueObjects=rhs.opaqueObjects;
		transparentObjects=rhs.transparentObjects;
	}
}
auto each(alias f,B,T...)(ref ObjectManager!B objectManager,T args){
	with(objectManager){
		opaqueObjects.each!f(args);
		transparentObjects.each!f(args);
	}
}
auto eachMoving(alias f,B,T...)(ref ObjectManager!B objectManager,T args){
	with(objectManager){
		opaqueObjects.eachMoving!f(args);
		transparentObjects.eachMoving!f(args);
	}
}
auto eachByType(alias f,B,T...)(ref ObjectManager!B objectManager,T args){
	with(objectManager){
		opaqueObjects.eachByType!f(args);
		transparentObjects.eachByType!f(args);
	}
}

void setCreatureState(B)(ref MovingObject!B object,ObjectState!B state){
	auto sacObject=object.sacObject;
	final switch(object.creatureState.mode){
		case CreatureMode.idle:
			if(object.creatureState.movement!=CreatureMovement.flying) object.frame=0;
			if(object.frame==0) object.animationState=AnimationState.stance1; // TODO: check health, maybe put stance2
			if(sacObject.mustFly) object.creatureState.movement=CreatureMovement.flying;
			final switch(object.creatureState.movement){
				case CreatureMovement.onGround:
					break;
				case CreatureMovement.flying:
					assert(sacObject.canFly);
					if(!sacObject.mustFly && (object.frame==0||object.animationState==AnimationState.fly&&object.sacObject.seamlessFlyAndHover))
						object.animationState=AnimationState.hover;
					break;
				case CreatureMovement.tumbling:
					object.frame=0;
					object.animationState=AnimationState.tumble;
					break;
			}
			if(object.frame==0&&object.creatureState.movement!=CreatureMovement.tumbling&&!state.uniform(5)){ // TODO: figure out the original rule for this
				with(AnimationState) if(sacObject.mustFly){
					static immutable idleCandidatesFlying=[hover,idle0,idle1,idle2,idle3]; // TODO: probably idleness animations depend on health
					object.pickRandomAnimation(idleCandidatesFlying,state);
				}else if(object.creatureState.movement==CreatureMovement.onGround){
					static immutable idleCandidatesOnGround=[idle0,idle1,idle2,idle3]; // TODO: probably idleness animations depend on health
					object.pickRandomAnimation(idleCandidatesOnGround,state);
				}
			}
			break;
		case CreatureMode.moving:
			final switch(object.creatureState.movement) with(CreatureMovement){
				case onGround:
					if(!object.sacObject.canRun){
						if(object.sacObject.canFly) object.startFlying(state);
						else object.startIdling(state);
						return;
					}
					object.frame=0;
					object.animationState=AnimationState.run;
					break;
				case flying:
					if(object.frame==0||object.animationState==AnimationState.hover&&object.sacObject.seamlessFlyAndHover)
						object.animationState=AnimationState.fly;
					break;
				case tumbling:
					object.creatureState.mode=CreatureMode.idle;
					break;
			}
			if(object.creatureState.mode==CreatureMode.idle)
				goto case CreatureMode.idle;
			break;
		case CreatureMode.dying:
			object.frame=0;
			final switch(object.creatureState.movement) with(CreatureMovement) with(AnimationState){
				case onGround:
					assert(!object.sacObject.mustFly);
					static immutable deathCandidatesOnGround=[death0,death1,death2];
					object.pickRandomAnimation(deathCandidatesOnGround,state);
					break;
				case flying:
					if(object.sacObject.mustFly){
						static immutable deathCandidatesFlying=[flyDeath,death0,death1,death2];
						object.pickRandomAnimation(deathCandidatesFlying,state);
					}else object.animationState=flyDeath;
					break;
				case tumbling:
					object.animationState=falling;
					break;
			}
			break;
		case CreatureMode.dead:
			object.frame=0;
			object.animationState=AnimationState.death0;
			if(sacObject.mustFly)
				object.animationState=AnimationState.hitFloor;
			object.frame=sacObject.numFrames(object.animationState)*updateAnimFactor-1;
			break;
		case CreatureMode.takeoff:
			assert(sacObject.canFly && object.creatureState.movement==CreatureMovement.onGround);
			if(!sacObject.hasAnimationState(AnimationState.takeoff)){
				object.creatureState.movement=CreatureMovement.flying;
				if(sacObject.movingAfterTakeoff){
					object.creatureState.mode=CreatureMode.moving;
					goto case CreatureMode.moving;
				}else{
					object.creatureState.mode=CreatureMode.idle;
					goto case CreatureMode.idle;
				}
			}
			object.frame=0;
			object.animationState=AnimationState.takeoff;
			break;
		case CreatureMode.landing:
			if(object.frame==0){
				if(object.creatureState.movement==CreatureMovement.onGround){
					object.creatureState.mode=CreatureMode.idle;
					goto case CreatureMode.idle;
				}else if(object.position.z<=state.getGroundHeight(object.position)){
					object.creatureState.movement=CreatureMovement.onGround;
					if(!object.sacObject.hasAnimationState(AnimationState.land)){
						object.creatureState.mode=CreatureMode.idle;
						goto case CreatureMode.idle;
					}
					object.animationState=AnimationState.land;
				}else if(object.animationState==AnimationState.fly){
					object.animationState=AnimationState.hover;
				}else assert(object.animationState==AnimationState.hover);
			}
			break;
		case CreatureMode.meleeAttacking:
			final switch(object.creatureState.movement) with(CreatureMovement) with(AnimationState){
				case onGround:
					object.frame=0;
					static immutable attackCandidatesOnGround=[attack0,attack1,attack2];
					object.pickRandomAnimation(attackCandidatesOnGround,state);
					break;
				case flying:
					object.frame=0;
					object.animationState=flyAttack;
					break;
				case tumbling:
					assert(0);
			}
	}
}

void pickRandomAnimation(B)(ref MovingObject!B object,immutable(AnimationState)[] candidates,ObjectState!B state){
	auto filtered=candidates.filter!(x=>object.sacObject.hasAnimationState(x));
	int len=cast(int)filtered.walkLength;
	assert(!!len&&object.frame==0);
	object.animationState=filtered.drop(state.uniform(len)).front;
}

void startIdling(B)(ref MovingObject!B object, ObjectState!B state){
	if(!object.creatureState.mode!=CreatureMode.moving) return;
	object.creatureState.mode=CreatureMode.idle;
	object.setCreatureState(state);
}

void kill(B)(ref MovingObject!B object, ObjectState!B state){
	with(CreatureMode) if(object.creatureState.mode.among(dying,dead)) return;
	if(!object.sacObject.canDie()) return;
	object.creatureState.mode=CreatureMode.dying;
	object.setCreatureState(state);
}

void immediateResurrect(B)(ref MovingObject!B object,ObjectState!B state){
	with(CreatureMode) if(!object.creatureState.mode.among(dying,dead)) return;
	object.creatureState.mode=CreatureMode.idle;
	object.setCreatureState(state);
}

void startFlying(B)(ref MovingObject!B object,ObjectState!B state){
	with(CreatureMode)
		if(!object.sacObject.canFly||!object.creatureState.mode.among(idle,moving)||
		   object.creatureState.movement!=CreatureMovement.onGround)
			return;
	object.creatureState.mode=CreatureMode.takeoff;
	object.setCreatureState(state);
}

void land(B)(ref MovingObject!B object,ObjectState!B state){
	with(CreatureMode)
		if(object.sacObject.mustFly||!object.creatureState.mode.among(idle,moving)||
		   object.creatureState.movement!=CreatureMovement.flying)
			return;
	if(!state.isOnGround(object.position))
		return;
	object.creatureState.mode=CreatureMode.landing;
	object.setCreatureState(state);
}

void startMeleeAttacking(B)(ref MovingObject!B object,ObjectState!B state){
	with(CreatureMode) with(CreatureMovement)
		if(!object.creatureState.mode.among(idle,moving)||
		   !object.creatureState.movement.among(onGround,flying)||
		   !object.sacObject.canAttack)
			return;
	object.creatureState.mode=CreatureMode.meleeAttacking;
	object.setCreatureState(state);
}

void setMovement(B)(ref MovingObject!B object,MovementDirection direction,ObjectState!B state){
	// TODO: also check for conditions that immobilze a creature, such as vines or spell casting
	with(CreatureMode)
		if(!object.creatureState.mode.among(idle,moving))
			return;
	if(object.creatureState.movement==CreatureMovement.flying &&
	   direction==MovementDirection.backward &&
	   !object.sacObject.canFlyBackward)
		return;
	auto newMode=direction==MovementDirection.none?CreatureMode.idle:CreatureMode.moving;
	if(object.creatureState.movementDirection==direction)
		return;
	object.creatureState.movementDirection=direction;
	object.setCreatureState(state);
}
void stopMovement(B)(ref MovingObject!B object,ObjectState!B state){
	object.setMovement(MovementDirection.none,state);
}
void startMovingForward(B)(ref MovingObject!B object,ObjectState!B state){
	object.setMovement(MovementDirection.forward,state);
}
void startMovingBackward(B)(ref MovingObject!B object,ObjectState!B state){
	object.setMovement(MovementDirection.backward,state);
}

void setTurning(B)(ref MovingObject!B object,RotationDirection direction,ObjectState!B state){
	with(CreatureMode)
		if(!object.creatureState.mode.among(idle,moving))
			return;
	// TODO: also check for conditions that immobilze a creature, such as vines or spell casting
	object.creatureState.rotationDirection=direction;
}
void stopTurning(B)(ref MovingObject!B object,ObjectState!B state){
	object.setTurning(RotationDirection.none,state);
}
void startTurningLeft(B)(ref MovingObject!B object,ObjectState!B state){
	object.setTurning(RotationDirection.left,state);
}
void startTurningRight(B)(ref MovingObject!B object,ObjectState!B state){
	object.setTurning(RotationDirection.right,state);
}

void updateCreatureState(B)(ref MovingObject!B object, ObjectState!B state){
	auto sacObject=object.sacObject;
	final switch(object.creatureState.mode){
		case CreatureMode.idle, CreatureMode.moving:
			object.frame+=1;
			auto oldMode=object.creatureState.mode;
			object.creatureState.mode=object.creatureState.movementDirection==MovementDirection.none?CreatureMode.idle:CreatureMode.moving;
			if(object.frame>=sacObject.numFrames(object.animationState)*updateAnimFactor){
				object.frame=0;
				object.setCreatureState(state);
			}else if(object.creatureState.mode!=oldMode){
				object.setCreatureState(state);
			}
			break;
		case CreatureMode.dying:
			with(AnimationState) assert(object.animationState.among(death0,death1,death2,flyDeath,falling,hitFloor),text(object.sacObject.tag," ",object.animationState));
			if(object.creatureState.movement==CreatureMovement.tumbling){
				if(state.isOnGround(object.position)){
					if(object.position.z<=state.getGroundHeight(object.position)){
						object.creatureState.movement=CreatureMovement.onGround;
						object.animationState=AnimationState.hitFloor;
						object.frame=0;
						break;
					}
				}
			}
			object.frame+=1;
			if(object.frame>=sacObject.numFrames(object.animationState)*updateAnimFactor){
				object.frame=0;
				final switch(object.creatureState.movement){
					case CreatureMovement.onGround:
						object.frame=sacObject.numFrames(object.animationState)*updateAnimFactor-1;
						object.creatureState.mode=CreatureMode.dead;
						break;
					case CreatureMovement.flying:
						object.creatureState.movement=CreatureMovement.tumbling;
						object.creatureState.fallingSpeed=Vector3f(0.0f,0.0f,0.0f);
						object.setCreatureState(state);
						break;
					case CreatureMovement.tumbling:
						// continue tumbling
						break;
				}
			}
			break;
		case CreatureMode.dead:
			with(AnimationState) assert(object.animationState.among(hitFloor,death0,death1,death2));
			assert(object.frame==sacObject.numFrames(object.animationState)*updateAnimFactor-1);
			break;
		case CreatureMode.takeoff:
			assert(object.sacObject.canFly);
			assert(object.creatureState.movement==CreatureMovement.onGround);
			object.frame+=1;
			if(object.frame>=sacObject.numFrames(object.animationState)*updateAnimFactor){
				object.frame=0;
				if(object.animationState==AnimationState.takeoff){
					object.creatureState.mode=object.sacObject.movingAfterTakeoff?CreatureMode.moving:CreatureMode.idle;
					object.creatureState.movement=CreatureMovement.flying;
				}
				object.setCreatureState(state);
			}
			break;
		case CreatureMode.landing:
			assert(object.sacObject.canFly&&!object.sacObject.mustFly);
			object.frame+=1;
			if(object.frame>=sacObject.numFrames(object.animationState)*updateAnimFactor){
				object.frame=0;
				object.setCreatureState(state);
			}
			break;
		case CreatureMode.meleeAttacking:
			object.frame+=1;
			if(object.frame>=sacObject.numFrames(object.animationState)*updateAnimFactor){
				object.frame=0;
				object.creatureState.mode=CreatureMode.idle;
				object.setCreatureState(state);
			}
			break;
	}
}

void updateCreaturePosition(B)(ref MovingObject!B object, ObjectState!B state){
	if(object.creatureState.mode.among(CreatureMode.idle,CreatureMode.moving,CreatureMode.landing,CreatureMode.dying)){
		auto rotationSpeed=object.sacObject.rotationSpeed/updateFPS;
		bool isRotating=false;
		if(object.creatureState.mode.among(CreatureMode.idle,CreatureMode.moving)&&
		   object.creatureState.movement!=CreatureMovement.tumbling
		){
			final switch(object.creatureState.rotationDirection){
				case RotationDirection.none:
					break;
				case RotationDirection.left:
					isRotating=true;
					object.creatureState.facing+=rotationSpeed;
					break;
				case RotationDirection.right:
					isRotating=true;
					object.creatureState.facing-=rotationSpeed;
				break;
			}
		}
		auto facing=facingQuaternion(object.creatureState.facing);
		auto newRotation=facing;
		if(object.creatureState.movement==CreatureMovement.onGround||
		   object.animationState==AnimationState.land
		){
			final switch(object.sacObject.rotateOnGround){
				case RotateOnGround.no:
					break;
				case RotateOnGround.sideways:
					newRotation=newRotation*rotationQuaternion(Axis.y,-atan(state.getGroundHeightDerivative(object.position, rotate(facing, Vector3f(1.0f,0.0f,0.0f)))));
					break;
				case RotateOnGround.completely:
					newRotation=newRotation*rotationQuaternion(Axis.x,atan(state.getGroundHeightDerivative(object.position, rotate(facing, Vector3f(0.0f,1.0f,0.0f)))));
					newRotation=newRotation*rotationQuaternion(Axis.y,-atan(state.getGroundHeightDerivative(object.position, rotate(facing, Vector3f(1.0f,0.0f,0.0f)))));
					break;
			}
		}
		if(isRotating||object.creatureState.mode!=CreatureMode.idle){
			auto diff=newRotation*object.rotation.conj();
			if(!isRotating){
				if(object.creatureState.movement==CreatureMovement.flying){
					rotationSpeed/=5;
				}else rotationSpeed/=2;
			}else rotationSpeed*=1.1f; // TODO: make rotation along z direction independent of remaining rotations?
			object.rotation=(limitRotation(diff,rotationSpeed)*object.rotation).normalized;
		}
	}
	auto facing=facingQuaternion(object.creatureState.facing);
	final switch(object.creatureState.movement){
		case CreatureMovement.onGround:
			if(object.creatureState.mode!=CreatureMode.moving) break;
			void applyMovementOnGround(Vector3f direction){
				auto speed=object.sacObject.movementSpeed(false)/updateFPS;
				auto derivative=state.getGroundHeightDerivative(object.position,direction);
				Vector3f newDirection=direction;
				if(derivative>0.0f){
					newDirection=Vector3f(direction.x,direction.y,derivative).normalized;
				}else if(derivative<0.0f){
					newDirection=Vector3f(direction.x,direction.y,derivative);
					auto maxFactor=object.sacObject.maxDownwardSpeedFactor;
					if(newDirection.lengthsqr>maxFactor*maxFactor) newDirection=maxFactor*newDirection.normalized;
				}
				object.position=state.moveOnGround(object.position,speed*newDirection);
			}
			final switch(object.creatureState.movementDirection){
				case MovementDirection.none:
					break;
				case MovementDirection.forward:
					applyMovementOnGround(rotate(facingQuaternion(object.creatureState.facing), Vector3f(0.0f,1.0f,0.0f)));
					break;
				case MovementDirection.backward:
					applyMovementOnGround(rotate(facingQuaternion(object.creatureState.facing), Vector3f(0.0f,-1.0f,0.0f)));
					break;
			}
			break;
		case CreatureMovement.flying:
			if(object.creatureState.mode==CreatureMode.landing ||
			   object.creatureState.mode==CreatureMode.idle&&object.animationState!=AnimationState.fly&&object.creatureState.flyingDisplacement>0.0f
			){
				auto downwardSpeed=object.creatureState.mode==CreatureMode.landing?object.sacObject.landingSpeed/updateFPS:object.sacObject.downwardHoverSpeed/updateFPS;
				object.position.z-=downwardSpeed;
				object.creatureState.flyingDisplacement=max(0.0f,object.creatureState.flyingDisplacement-downwardSpeed);
				if(state.isOnGround(object.position)){
					auto height=state.getGroundHeight(object.position);
					if(object.position.z<=height)
						object.position.z=height;
					object.creatureState.flyingDisplacement=min(object.creatureState.flyingDisplacement,object.position.z-height);
				}
				break;
			}
			if(object.creatureState.mode!=CreatureMode.moving) break;
			void applyMovementInAir(Vector3f direction){
				auto speed=object.sacObject.movementSpeed(true)/updateFPS;
				auto newPosition=object.position+speed*direction;
				auto upwardSpeed=max(0.0f,min(object.sacObject.takeoffSpeed/updateFPS,object.sacObject.flyingHeight-object.creatureState.flyingDisplacement));
				auto onGround=state.isOnGround(newPosition), newHeight=float.nan;
				if(onGround){
					newHeight=state.getGroundHeight(newPosition);
					if(newHeight>newPosition.z)
						upwardSpeed+=newHeight-newPosition.z;
				}
				auto upwardFactor=object.sacObject.upwardFlyingSpeedFactor;
				auto downwardFactor=object.sacObject.downwardFlyingSpeedFactor;
				auto newDirection=Vector3f(direction.x,direction.y,direction.z+upwardSpeed).normalized;
				speed*=sqrt(newDirection.x^^2+newDirection.y^^2+(newDirection.z*(newDirection.z>0?upwardFactor:downwardFactor))^^2);
				auto velocity=speed*newDirection;
				newPosition=object.position+velocity;
				object.creatureState.flyingDisplacement+=velocity.z;
				if(onGround){
					object.creatureState.flyingDisplacement=min(object.creatureState.flyingDisplacement,newPosition.z-newHeight);
					object.position.z=max(object.position.z,newHeight);
				}
				object.position=newPosition;
			}
			final switch(object.creatureState.movementDirection){
				case MovementDirection.none:
					break;
				case MovementDirection.forward:
					applyMovementInAir(rotate(object.rotation,Vector3f(0.0f,1.0f,0.0f)));
					break;
				case MovementDirection.backward:
					assert(object.sacObject.canFlyBackward);
					applyMovementInAir(rotate(object.rotation,Vector3f(0.0f,-1.0f,0.0f)));
					break;
			}
			break;
		case CreatureMovement.tumbling:
			object.creatureState.fallingSpeed.z-=object.sacObject.fallingAcceleration/updateFPS;
			object.position+=object.creatureState.fallingSpeed;
			if(object.creatureState.fallingSpeed.z<0 && state.isOnGround(object.position))
				object.position.z=max(object.position.z,state.getGroundHeight(object.position));
			break;
	}
}

void updateCreature(B)(ref MovingObject!B object, ObjectState!B state){
	object.updateCreatureState(state);
	object.updateCreaturePosition(state);
}

import std.random: MinstdRand0;
final class ObjectState(B){ // (update logic)
	SacMap!B map;
	this(SacMap!B map){ this.map=map; }
	bool isOnGround(Vector3f position){
		return map.isOnGround(position);
	}
	Vector3f moveOnGround(Vector3f position,Vector3f direction){
		return map.moveOnGround(position,direction);
	}
	float getGroundHeight(Vector3f position){
		return map.getGroundHeight(position);
	}
	float getGroundHeightDerivative(Vector3f position,Vector3f direction){
		return map.getGroundHeightDerivative(position,direction);
	}
	Vector2f sunSkyRelLoc(Vector3f cameraPos){
		return map.sunSkyRelLoc(cameraPos);
	}
	int frame=0;
	auto rng=MinstdRand0(1); // TODO: figure out what rng to use
	int uniform(int n){
		import std.random: uniform;
		return uniform(0,n,rng);
	}
	void copyFrom(ObjectState!B rhs){
		frame=rhs.frame;
		rng=rhs.rng;
		obj=rhs.obj;
	}
	void updateFrom(ObjectState!B rhs,Command[] frameCommands){
		copyFrom(rhs);
		update();
	}
	void update(){
		frame+=1;
		this.eachMoving!updateCreature(this);
	}
	ObjectManager!B obj;
	int addObject(T)(T object) if(is(T==MovingObject!B)||is(T==StaticObject!B)){
		return obj.addObject(object);
	}
	void addFixed(FixedObject!B object){
		obj.addFixed(object);
	}
}
auto each(alias f,B,T...)(ObjectState!B objectState,T args){
	return objectState.obj.each!f(args);
}
auto eachMoving(alias f,B,T...)(ObjectState!B objectState,T args){
	return objectState.obj.eachMoving!f(args);
}
auto eachByType(alias f,B,T...)(ObjectState!B objectState,T args){
	return objectState.obj.eachByType!f(args);
}

enum TargetType{
	floor,
	creature,
	structure,
}

struct Target{
	TargetType type;
	int targetId;

}

enum CommandType{
	moveForward,
	moveBack,
	turnLeft,
	turnRight,
}

struct Command{
	CommandType type;
	int creature;
	Target target;
}

final class GameState(B){
	ObjectState!B lastCommitted;
	ObjectState!B current;
	ObjectState!B next;
	Array!(Array!Command) commands;
	this(SacMap!B map,NTTs ntts,Options options)in{
		assert(!!map);
	}body{
		current=new ObjectState!B(map);
		next=new ObjectState!B(map);
		lastCommitted=new ObjectState!B(map);
		commands.length=1;
		foreach(ref structure;ntts.structures)
			placeStructure(structure);
		foreach(ref wizard;ntts.wizards)
			placeNTT(wizard);
		foreach(ref creature;ntts.creatures)
			placeNTT(creature);
		foreach(widgets;ntts.widgetss) // TODO: improve engine to be able to handle this
			placeWidgets(widgets);
		map.meshes=createMeshes!B(map.edges,map.heights,map.tiles,options.enableMapBottom); // TODO: allow dynamic retexuring
		commit();
	}
	void placeStructure(ref Structure ntt){
		import nttData;
		auto data=ntt.tag in bldgs;
		enforce(!!data);
		auto position=Vector3f(ntt.x,ntt.y,ntt.z);
		auto ci=cast(int)(position.x/10+0.5);
		auto cj=cast(int)(position.y/10+0.5);
		import bldg;
		if(data.flags&BldgFlags.ground){
			auto ground=data.ground;
			auto n=current.map.n,m=current.map.m;
			foreach(j;max(0,cj-4)..min(n,cj+4)){
				foreach(i;max(0,ci-4)..min(m,ci+4)){
					auto dj=j-(cj-4), di=i-(ci-4);
					if(ground[dj][di])
						current.map.tiles[j][i]=ground[dj][di];
				}
			}
		}
		foreach(ref component;data.components){
			auto curObj=SacObject!B.getBLDG(component.tag);
			auto offset=Vector3f(component.x,component.y,component.z);
			offset=rotate(facingQuaternion(2*PI/360.0f*ntt.facing), offset);
			auto cposition=position+offset;
			if(!current.isOnGround(cposition)) continue;
			cposition.z=current.getGroundHeight(cposition);
			auto rotation=facingQuaternion(2*PI/360.0f*(ntt.facing+component.facing));
			current.addObject(StaticObject!B(curObj,cposition,rotation));
		}
	}

	void placeNTT(T)(ref T ntt) if(is(T==Creature)||is(T==Wizard)){
		auto curObj=SacObject!B.getSAXS!T(ntt.tag);
		auto position=Vector3f(ntt.x,ntt.y,ntt.z);
		bool onGround=current.isOnGround(position);
		if(onGround)
			position.z=current.getGroundHeight(position);
		auto rotation=facingQuaternion(ntt.facing);
		auto mode=ntt.flags & Flags.corpse ? CreatureMode.dead : CreatureMode.idle;
		auto movement=curObj.mustFly?CreatureMovement.flying:CreatureMovement.onGround;
		if(movement==CreatureMovement.onGround && !onGround)
			movement=curObj.canFly?CreatureMovement.flying:CreatureMovement.tumbling;
		auto creatureState=CreatureState(mode, movement, ntt.facing);
		auto obj=MovingObject!B(curObj,position,rotation,AnimationState.stance1,0,creatureState);
		obj.setCreatureState(current);
		obj.updateCreaturePosition(current);
		/+do{
			import std.random: uniform;
			state=cast(AnimationState)uniform(0,64);
		}while(!curObj.hasAnimationState(state));+/
		current.addObject(obj);
	}
	void placeWidgets(Widgets w){
		auto curObj=SacObject!B.getWIDG(w.tag);
		foreach(pos;w.positions){
			auto position=Vector3f(pos[0],pos[1],0);
			if(!current.isOnGround(position)) continue;
			position.z=current.getGroundHeight(position);
			// original engine screws up widget rotations
			// values look like angles in degrees, but they are actually radians
			auto rotation=facingQuaternion(-pos[2]);
			current.addFixed(FixedObject!B(curObj,position,rotation));
		}
	}

	void step(){
		next.updateFrom(current,commands[current.frame].data);
		swap(current,next);
		if(commands.length<=current.frame) commands~=Array!Command();
	}
	void commit(){
		lastCommitted.copyFrom(current);
	}
	void rollback(int frame)in{
		assert(frame>=lastCommitted.frame);
	}body{
		if(frame!=current.frame) current.copyFrom(lastCommitted);
	}
	void simulateTo(int frame)in{
		assert(frame>=current.frame);
	}body{
		while(current.frame<frame)
			step();
	}
	void addCommand(int frame,Command command)in{
		assert(frame<=current.frame);
	}body{
		assert(frame<commands.length);
		auto currentFrame=current.frame;
		commands[frame]~=command;
		rollback(frame);
		simulateTo(currentFrame);
	}
}

