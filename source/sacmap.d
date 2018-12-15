import dlib.image, dlib.math, dlib.geometry;
import util;
import maps,txtr,envi;
import std.exception, std.string, std.algorithm, std.conv, std.range;
import std.stdio, std.path, std.file;
import std.typecons: tuple,Tuple;
import std.math;

import sacobject;

class SacMap(B){
	B.TerrainMesh[] meshes;
	B.Texture[] textures;
	B.Texture[] details;
	B.Texture color;
	B.Material[] materials;
	ubyte[] dti;
	int n,m;
	bool[][] edges;
	float[][] heights;
	ubyte[][] tiles;
	Envi envi;

	this(string filename){
		enforce(filename.endsWith(".HMAP"));
		auto hmap=loadHMap(filename);
		auto minHeight=1e9;
		foreach(h;hmap.heights) foreach(x;h) minHeight=min(minHeight,x);
		foreach(h;hmap.heights) foreach(ref x;h) x-=minHeight;
		envi=loadENVI(filename[0..$-".HMAP".length]~".ENVI");
		auto tmap=loadTMap(filename[0..$-".HMAP".length]~".TMAP");
		edges=hmap.edges;
		heights=hmap.heights;
		tiles=tmap.tiles;
		n=to!int(edges.length);
		m=to!int(edges[1].length);
		enforce(heights.length==n);
		enforce(edges.all!(x=>x.length==m));
		enforce(heights.all!(x=>x.length==m));
		import nttData: landFolders;
		auto land=landFolders[detectTileset(filename[0..$-".HMAP".length]~".LEVL")];
		dti=loadDTIndex(land).dts;
		auto mapts=loadMAPTs(land);
		auto bumps=loadDTs(land);
		auto edge=loadTXTR(buildPath(land,chain(retro(envi.edge[]),".TXTR").to!string));
		//auto sky_=loadTXTR(buildPath(land,chain(retro(envi.sky_[]),".TXTR").to!string)); // TODO: smk files
		auto sky_=loadTXTR(buildPath(land,"SKY_.TXTR"));
		auto skyb=loadTXTR(buildPath(land,chain(retro(envi.skyb[]),".TXTR").to!string));
		auto skyt=loadTXTR(buildPath(land,chain(retro(envi.skyt[]),".TXTR").to!string));
		auto sun_=loadTXTR(buildPath(land,chain(retro(envi.sun_[]),".TXTR").to!string));
		auto undr=loadTXTR(buildPath(land,chain(retro(envi.undr[]),".TXTR").to!string));
		auto mirroredRepeat=iota(256+6).map!(i=>i!=257);
		textures=zip(chain(mapts,only(edge,sky_,skyb,skyt,sun_,undr)),mirroredRepeat).map!(x=>B.makeTexture(x.expand)).array;
		details=bumps.map!(B.makeTexture).array;
		auto lmap=loadLMap(filename[0..$-".HMAP".length]~".LMAP");
		color=B.makeTexture(lmap);
		materials=B.createMaterials(this);
	}

	struct Sky{
		enum scaling=4*10.0f*256.0f;
		enum dZ=-0.05, undrZ=-0.25, skyZ=0.25, relCloudLoc=0.7;
		enum numSegs=64, numTextureRepeats=8;
		enum energy=1.7f;
	}

	Vector2f sunSkyRelLoc(Vector3f cameraPos){
		auto sunPos=Vector3f(0,0,Sky.skyZ*Sky.scaling);
		auto adjCamPos=cameraPos-Vector3f(1280.0f,1280.0f,Sky.dZ*Sky.scaling+1);
		float zDiff=sunPos.z-adjCamPos.z;
		float tZDiff=Sky.scaling*Sky.skyZ*(1-Sky.relCloudLoc);
		auto intersection=sunPos+(adjCamPos-sunPos)*tZDiff/zDiff;
		return intersection.xy/(Sky.scaling/2);
	}

	Tuple!(int,"j",int,"i") getTile(Vector3f pos){
		return tuple!("j","i")(cast(int)(n-1-pos.y/10),cast(int)(pos.x/10));
	}
	Vector3f getVertex(int j,int i){
		return Vector3f(10*i,10*(n-1-j),heights[j][i]);
	}

	Tuple!(int,"j",int,"i")[3] getTriangle(Vector3f pos){
		auto tile=getTile(pos);
		int i=tile.i,j=tile.j;
		if(i<0||i>=n-1||j<0||j>=m-1) return typeof(return).init;
		Tuple!(int,"j",int,"i")[3][2] tri;
		int nt=0;
		int di(int i){ return i==1||i==2; }
		int dj(int i){ return i==2||i==3; }
		void makeTri(int[] indices)(){
			foreach(k,ref x;tri[nt++]){
				x=tuple!("j","i")(j+dj(indices[k]),i+di(indices[k]));
			}
		}
		if(!edges[j][i]){
			if(!edges[j+1][i+1]&&!edges[j][i+1]) makeTri!([0,2,1]);
		}else if(!edges[j][i+1]&&!edges[j+1][i+1]&&!edges[j+1][i]) makeTri!([1,3,2]);
		if(!edges[j+1][i+1]){
			if(!edges[j][i]&&!edges[j+1][i]) makeTri!([2,0,3]);
		}else if(!edges[j][i]&&!edges[j][i+1]&&!edges[j+1][i]) makeTri!([0,3,1]);
		bool isInside(Tuple!(int,"j",int,"i")[3] tri){
			Vector3f getV(int k){
				auto v=getVertex(tri[k%$].j,tri[k%$].i)-pos;
				v.z=0;
				return v;
			}
			foreach(k;0..3){
				if(cross(getV(k),getV(k+1)).z<0)
					return false;
			}
			return true;
		}
		if(nt==0) return typeof(return).init;
		if(isInside(tri[0])) return tri[0]; // TODO: fix precision issues, by using fixed-point and splitting at line
		else if(nt==2) return tri[1];
		else return typeof(return).init;
	}

	bool isOnGround(Vector3f pos){
		auto triangle=getTriangle(pos);
		return triangle[0]!=triangle[1];
	}
	float getGroundHeight(Vector3f pos){
		auto triangle=getTriangle(pos);
		static foreach(i;0..3)
			mixin(text(`auto p`,i,`=getVertex(triangle[`,i,`].expand);`));
		Plane plane;
		plane.fromPoints(p0,p1,p2); // wtf.
		return -(plane.a*pos.x+plane.b*pos.y+plane.d)/plane.c;
	}
}

SuperImage loadLMap(string filename){
	enforce(filename.endsWith(".LMAP"));
	auto img=image(256,256,4);
	auto idata=img.data,data=readFile(filename);
	enforce(idata.length==data.length);
	img.data[]=data[];
	return img;
}

SuperImage[] loadDTs(string directory){
	auto r=iota(0,7).until!(i=>!exists(buildPath(directory,format("DT%02d.TXTR",i)))).map!(i=>loadTXTR(buildPath(directory,format("DT%02d.TXTR",i)))).array;
	foreach(ref img;r){
		foreach(j;0..256){
			foreach(i;0..256){
				img[j,i]=Color4f(img[j,i].r,img[j,i].g,img[j,i].b,img[j,i].b);
			}
		}
	}
	return r;
}

SuperImage[] loadMAPTs(string directory){
	auto palFile=buildPath(directory, "LAND.PALT");
	auto palt=readFile(palFile);
	palt=palt[8..$]; // header bytes (TODO: figure out what they mean)
	return iota(0,256).map!((i){
			auto maptFile=buildPath(directory,format("%04d.MAPT",i));
			auto img=image(64,64);
			if(!exists(maptFile)) return img;
			auto data=readFile(maptFile);
			foreach(y;0..64){
				foreach(x;0..64){
					uint ccol=data[64*y+x];
					img[x,y]=Color4f(Color4(palt[3*ccol],palt[3*ccol+1],palt[3*ccol+2]));
				}
			}
			return img;
		}).array;
}

B.TerrainMesh[] createMeshes(B)(bool[][] edges, float[][] heights, ubyte[][] tiles, float scaleFactor=1){
	//foreach(e;edges) e[]=false;
	auto n=to!int(edges.length);
	enforce(n);
	auto m=to!int(edges[0].length);
	enforce(heights.length==n);
	enforce(edges.all!(x=>x.length==m));
	enforce(heights.all!(x=>x.length==m));
	Vector3f getVertex(int j,int i){
		return scaleFactor*Vector3f(10*i,10*(n-1-j),heights[j][i]);
	}
	int di(int i){ return i==1||i==2; }
	int dj(int i){ return i==2||i==3; }
	auto getFaces(O)(int j,int i,O o){
		if(!edges[j][i]){
			if(!edges[j+1][i+1]&&!edges[j][i+1]) o.put([0,2,1]);
		}else if(!edges[j][i+1]&&!edges[j+1][i+1]&&!edges[j+1][i]) o.put([1,3,2]);
		if(!edges[j+1][i+1]){
			if(!edges[j][i]&&!edges[j+1][i]) o.put([2,0,3]);
		}else if(!edges[j][i]&&!edges[j][i+1]&&!edges[j+1][i]) o.put([0,3,1]);
	}
	auto normals=new Vector3f[][](n,m);
	foreach(j;0..n) normals[j][]=Vector3f(0,0,0);
	foreach(j;0..n-1){
		foreach(i;0..m-1){
			struct ProcessFaces{
				void put(uint[3] f){
					Vector3f[3] v;
					foreach(k;0..3){
						v[k]=getVertex(j+dj(f[k]),i+di(f[k]));
					}
					Vector3f p=cross(v[1]-v[0],v[2]-v[0]);
					foreach(k;0..3){
						normals[j+dj(f[k])][i+di(f[k])]+=p;
					}
				}
			}
			getFaces(j,i,ProcessFaces());
		}
	}
	foreach(j;0..n)
		foreach(i;0..m)
			normals[j][i]=normals[j][i].normalized;
	auto numVertices=new uint[](256);
	auto numFaces=new uint[](256);
	foreach(j;0..n-1){
		foreach(i;0..m-1){
			auto t=tiles[n-2-j][i];
			int faces=0;
			struct FaceCounter{
				void put(uint[3]){
					faces++;
				}
			}
			getFaces(j,i,FaceCounter());
			if(faces){
				numVertices[t]+=4;
				numFaces[t]+=faces;
			}
		}
	}
	auto curVertex=new uint[](256);
	auto curFace=new uint[](256);
	auto meshes=new B.TerrainMesh[](257);
	foreach(j;0..n-1){
		foreach(i;0..m-1){
			auto t=tiles[n-2-j][i];
			if(!meshes[t]){
				if(!numFaces[t]) continue;
				meshes[t]=B.makeTerrainMesh(numVertices[t], numFaces[t]);
			}
			int faces=0;
			struct FaceCounter2{
				void put(uint[3]){
					faces++;
				}
			}
			getFaces(j,i,FaceCounter2());
			if(!faces) continue;
			foreach(k;0..4){
				meshes[t].vertices[curVertex[t]+k]=getVertex(j+dj(k),i+di(k));
				meshes[t].normals[curVertex[t]+k]=normals[j+dj(k)][i+di(k)];
				meshes[t].coords[curVertex[t]+k]=Vector2f(i+di(k),n-1-(j+dj(k)))/256.0f;
				meshes[t].texcoords[curVertex[t]+k]=Vector2f(di(k),!dj(k));
			}
			struct ProcessFaces2{
				void put(uint[3] f){
					meshes[t].indices[curFace[t]++]=[curVertex[t]+f[0],curVertex[t]+f[1],curVertex[t]+f[2]];
				}
			}
			getFaces(j,i,ProcessFaces2());
			curVertex[t]+=4;
		}
	}
	assert(curVertex==numVertices && curFace==numFaces);
	Vector3f[] edgeVertices;
	Vector3f[] edgeNormals;
	Vector2f[] edgeCoords;
	Vector2f[] edgeTexcoords;
	uint[3][] edgeFaces;
	enum mapDepth=50.0f;
	foreach(j;0..n-1){
		foreach(i;0..m-1){
			void makeEdge(R,S)(int x1,int y1,int x2,int y2,R mustBeEdges,S someNonEdge){
				if(!mustBeEdges.all!((k)=>edges[k[1]][k[0]])||
				   edges[y1][x1]||edges[y2][x2]||!someNonEdge.any!((k)=>!edges[k[1]][k[0]])) return;
				auto off=to!uint(edgeVertices.length);
				edgeVertices~=[getVertex(y1,x1),getVertex(y2,x2),getVertex(y2,x2)+Vector3f(0,0,-mapDepth),getVertex(y1,x1)+Vector3f(0,0,-mapDepth)];
				auto normal=cross(edgeVertices[$-3]-edgeVertices[$-1],edgeVertices[$-2]-edgeVertices[$-1]);
				foreach(k;0..4) edgeNormals~=normal.normalized;
				edgeCoords~=[Vector2f(x1,n-1-y1)/256.0,Vector2f(x2,n-1-y2)/256.0,Vector2f(x2,n-1-y2)/256.0,Vector2f(x1,n-1-y1)/256.0];
				edgeTexcoords~=[Vector2f(0,0),Vector2f(1,0),Vector2f(1,1),Vector2f(0,1)];
				edgeFaces~=[[off+0,off+1,off+2],[off+2,off+3,off+0]];
			}
			makeEdge(i,j,i+1,j,only(tuple(i,j-1),tuple(i+1,j-1)).filter!(x=>!!j),only(tuple(i,j+1),tuple(i+1,j+1)));
			makeEdge(i+1,j+1,i,j+1,only(tuple(i+1,j+2),tuple(i,j+2)).filter!(x=>j+1!=n-1),only(tuple(i,j),tuple(i+1,j)));
			makeEdge(i,j+1,i,j,only(tuple(i-1,j+1),tuple(i-1,j)).filter!(x=>!!i),only(tuple(i+1,j+1),tuple(i+1,j)));
			makeEdge(i+1,j,i+1,j+1,only(tuple(i+2,j),tuple(i+2,j+1)).filter!(x=>i+1!=m-1),only(tuple(i,j),tuple(i,j+1)));
			makeEdge(i,j,i+1,j+1,only(tuple(i+1,j)),only(tuple(i,j+1)));
			makeEdge(i+1,j,i,j+1,only(tuple(i+1,j+1)),only(tuple(i,j)));
			makeEdge(i+1,j+1,i,j,only(tuple(i,j+1)),only(tuple(i+1,j)));
			makeEdge(i,j+1,i+1,j,only(tuple(i,j)),only(tuple(i+1,j+1)));
		}
	}
	meshes[256]=B.makeTerrainMesh(edgeVertices.length,edgeFaces.length);
	meshes[256].vertices[]=edgeVertices[];
	meshes[256].normals[]=edgeNormals[];
	meshes[256].coords[]=edgeCoords[];
	meshes[256].texcoords[]=edgeTexcoords[];
	meshes[256].indices[]=edgeFaces[];
	foreach(mesh;meshes){
		if(!mesh) continue;
		B.finalizeTerrainMesh(mesh);
	}
	return meshes;
}
