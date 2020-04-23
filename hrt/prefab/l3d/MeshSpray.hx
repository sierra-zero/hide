package hrt.prefab.l3d;

import h3d.Vector;
import hxd.Key as K;

typedef Mesh = {
	var path: String;
	var isRef: Bool;
}

typedef Set = {
	var name: String;
	var meshes: Array<Mesh>;
}

typedef SetGroup = {
	var name: String;
	var sets: Array<Set>;
}

class MeshSpray extends Object3D {

	#if editor

	var meshes : Array<Mesh> = []; // specific set for this mesh spray
	var sceneEditor : hide.comp.SceneEditor;

	var density : Int = 10;
	var densityOffset : Int = 0;
	var radius : Float = 10.0;
	var deleteRadius : Float = 10.0;
	var scale : Float = 1.0;
	var scaleOffset : Float = 0.1;
	var rotation : Float = 0.0;
	var rotationOffset : Float = 0.0;

	var dontRepeatMesh : Bool = false;
	var lastIndexMesh = -1;
	
	var currentPresetName : String = null;
	var currentSetName : String = null;

	var allSetGroups : Array<SetGroup>;
	var setGroup : SetGroup;
	var currentSet : Set;

	var currentMeshes(get, null) : Array<Mesh>;
	function get_currentMeshes() {
		if (currentSet != null) 
			return currentSet.meshes;
		else
			return meshes;
	}

	var sprayEnable : Bool = false;
	var interactive : h2d.Interactive;
	var gBrushes : Array<h3d.scene.Mesh>;

	var timerCicle : haxe.Timer;

	var lastSpray : Float = 0;

	#end

	public function new( ?parent ) {
		super(parent);
		type = "meshBatch";
	}

	#if editor

	var MESH_SPRAY_CONFIG_FILE = "meshSprayProps.json";
	var MESH_SPRAY_CONFIG_PATH(get, null) : String;
	function get_MESH_SPRAY_CONFIG_PATH() {
		return hide.Ide.inst.resourceDir + "/" + MESH_SPRAY_CONFIG_FILE;
	}

	override function save() {
		var obj : Dynamic = {};
		obj.x = obj.y = obj.z = 0;
		obj.meshes = meshes;
		obj.dontRepeatMesh = dontRepeatMesh;
		obj.currentPresetName = currentPresetName;
		obj.currentSetName = currentSetName;
		obj.density = density;
		obj.densityOffset = densityOffset;
		obj.radius = radius;
		obj.deleteRadius = deleteRadius;
		obj.scale = scale;
		obj.scaleOffset = scaleOffset;
		obj.rotation = rotation;
		obj.rotationOffset = rotationOffset;
		return obj;
	}

	override function load( obj : Dynamic ) {
		x = y = z = 0;
		if (obj.meshes != null)
			meshes = obj.meshes;
		if (obj.density != null)
			density = obj.density;
		if (obj.densityOffset != null)
			densityOffset = obj.densityOffset;
		if (obj.radius != null)
			radius = obj.radius;
		if (obj.deleteRadius != null)
			deleteRadius = obj.deleteRadius;
		if (obj.scale != null)
			scale = obj.scale;
		if (obj.scaleOffset != null)
			scaleOffset = obj.scaleOffset;
		if (obj.rotation != null)
			rotation = obj.rotation;
		if (obj.rotationOffset != null)
			rotationOffset = obj.rotationOffset;
		dontRepeatMesh = obj.dontRepeatMesh;
		if (obj.currentPresetName != null)
			currentPresetName = obj.currentPresetName;
		if (obj.currentSetName != null)
			currentSetName = obj.currentSetName;
	}

	override function getHideProps() : HideProps {
		return { icon : "paint-brush", name : "MeshSpray" };
	}

	function extractMeshName( path : String ) : String {
		if( path == null ) return "None";
		var childParts = path.split("/");
		return childParts[childParts.length - 1].split(".")[0];
	}

	function saveConfigMeshBatch() {
		sys.io.File.saveContent(MESH_SPRAY_CONFIG_PATH, hide.Ide.inst.toJSON(allSetGroups));
	}

	var wasEdited = false;

	var previewModels : Array<hrt.prefab.Prefab> = [];
	override function edit( ectx : EditContext ) {
		if (sceneEditor == null) {
			allSetGroups = if( sys.FileSystem.exists(MESH_SPRAY_CONFIG_PATH) )
				try hide.Ide.inst.parseJSON(sys.io.File.getContent(MESH_SPRAY_CONFIG_PATH)) catch( e : Dynamic ) throw e+" (in "+MESH_SPRAY_CONFIG_PATH+")";
			else
				[];
		}
		sceneEditor = ectx.scene.editor;


		var ctx = ectx.getContext(this);
		var s2d = @:privateAccess ctx.local2d.getScene();
		interactive = new h2d.Interactive(10000, 10000, s2d);
		interactive.propagateEvents = true;
		interactive.cancelEvents = false;

		interactive.onWheel = function(e) {

		};

		interactive.onKeyUp = function(e) {
			if (e.keyCode == hxd.Key.R) {
				lastMeshId = -1;
				if (lastSpray < Date.now().getTime() - 100) {
					if( !K.isDown( K.SHIFT) ) {
						if (previewModels.length > 0) {
							sceneEditor.deleteElements(previewModels, () -> { }, false);
							sceneEditor.selectObjects([this]);
							previewModels = [];
						}
						var worldPos = getMousePicker(s2d.mouseX, s2d.mouseY);
						previewMeshesAround(ctx, worldPos);
					}
					lastSpray = Date.now().getTime();
				}
			}
		}

		interactive.onPush = function(e) {
			e.propagate = false;
			sprayEnable = true;
			var worldPos = getMousePicker(s2d.mouseX, s2d.mouseY);
			if( K.isDown( K.SHIFT) )
				removeMeshesAround(ctx, worldPos);
			else {
				addMeshes(ctx);
			}
		};

		interactive.onRelease = function(e) {
			e.propagate = false;
			sprayEnable = false;

			if (previewModels.length > 0) {
				sceneEditor.deleteElements(previewModels, () -> { }, false);
				sceneEditor.selectObjects([this], Nothing);
				previewModels = [];
			}
		};

		interactive.onMove = function(e) {
			var worldPos = getMousePicker(s2d.mouseX, s2d.mouseY);

			var shiftPressed = K.isDown( K.SHIFT);

			drawCircle(ctx, worldPos.x, worldPos.y, worldPos.z, (shiftPressed) ? deleteRadius : radius, 5, (shiftPressed) ? 9830400 : 38400);

			if (lastSpray < Date.now().getTime() - 100) {
				if (previewModels.length > 0) {
					sceneEditor.deleteElements(previewModels, () -> { }, false, false);
					previewModels = [];
				}
				if( !shiftPressed ) {
					previewMeshesAround(ctx, worldPos);
				}

				if( K.isDown( K.MOUSE_LEFT) ) {
					e.propagate = false;

					if (sprayEnable) {
						if( shiftPressed ) {
							removeMeshesAround(ctx, worldPos);
						} else {
							addMeshes(ctx);
							if (density == 1) sprayEnable = false;
						}
					}
				}
				lastSpray = Date.now().getTime();
			}
		};

		var props = new hide.Element('<div class="group" name="Meshes"></div>');
		
		var preset = new hide.Element('<div class="btn-list" align="center" ></div>').appendTo(props);

		var presetChoice = new hide.Element('<div align="center" ></div>').appendTo(preset);

		var selectPresetElt = new hide.Element('<select style="width: 150px" ></select>').appendTo(presetChoice);

		function updateSelectPreset() {
			selectPresetElt.empty();
			var allSetGroupsName = [null];
			for (g in allSetGroups) allSetGroupsName.push(g.name);
			for (presetValue in allSetGroupsName) {
				var selected = (currentPresetName == presetValue);
				var presetName = (presetValue == null) ? "No preset" : presetValue;
				selectPresetElt.append(new hide.Element('<option ${(selected) ? 'selected=selected' : ''} value="${presetValue}"" >${presetName}</option>'));
			}
			selectPresetElt.append(new hide.Element('<option value="#add">-- Add preset --</option>'));
		}
		updateSelectPreset();

		var editPresetName = new hide.Element('<button>Edit</button>').appendTo(presetChoice);
		var deletePreset = new hide.Element('<button>Del.</button>').appendTo(presetChoice);

		var setsList = new hide.Element('<div align="center" ></div>').appendTo(preset);

		var selectElement = new hide.Element('<select multiple size="6" style="width: 300px" ></select>').appendTo(props);

		function onChangeSet() {
			selectElement.empty();
			for (m in currentMeshes.copy()) {
				var path : String = null;
				if (Std.is(m, String)) { // retro-compatibility
					path = cast m;
					currentMeshes.remove(m);
					addMeshPath(path);
				} else {
					path = m.path;
				}
				selectElement.append(new hide.Element('<option value="${path}">${extractMeshName(path)}</option>'));
			}
		}
		
		var selectedSetElt : hide.Element = null;
		function setSet(set: Set, setElt : hide.Element) {
			currentSetName = (set != null) ? set.name : null;
			currentSet = set;
			if (selectedSetElt != null)
				selectedSetElt.css("border-color", "#444444");
			selectedSetElt = setElt;
			if (selectedSetElt != null)
				selectedSetElt.css("border-color", "green");
			onChangeSet();
		}

		function onChangePreset() {
			if (currentPresetName != null) {
				var tmp = allSetGroups.filter(g -> g.name == currentPresetName);
				if (tmp.length > 0)
					setGroup = tmp[0];
				else
					return;
			} else {
				setGroup = null;
				setSet(null, null);
			}
			setsList.empty();
			if (setGroup != null) {
				for (s in setGroup.sets) {
					var setElt = new hide.Element('<div style="margin: 5px; padding: 10px; border: solid 1px #444444; display: inline-block;" ></div>').appendTo(setsList);
					var inputSetElt = new hide.Element('<input type="text" style="width: 75px; border: none; padding: 0; text-align: center;" value="${s.name}" />').appendTo(setElt);
					setElt.on("click", function(e) {
						setSet(s, setElt);
					});
					inputSetElt.on("change", function(e) {
						var value : String = inputSetElt.val();
						if (value != null && value.length > 0) {
							s.name = value;
							saveConfigMeshBatch();
						} else {
							inputSetElt.val(s.name);
						}
					});
					if (s.name == currentSetName) setSet(s, setElt);
				}
				var addSet = new hide.Element('<div style="margin: 5px; padding: 10px; border: solid 1px #444444; display: inline-block;" >Add set</div>').appendTo(setsList);
				addSet.on("click", function(e) {
					var name = hide.Ide.inst.ask("Name set:");
					if (name == null || name.length == 0) return;
					setGroup.sets.push({
						name: name,
						meshes: []
					});
					currentSetName = name;
					onChangePreset();
				});
			}
		}
		selectPresetElt.on("change", function() {
			var value = selectPresetElt.val();
			if (value == "null") value = null;
			if (value == "#add") {
				var name = hide.Ide.inst.ask("Name preset:");
				var groups = allSetGroups.filter(g -> g.name == name);
				if (name == null || name.length == 0 || groups.length > 0)
					return;
				allSetGroups.push({
					name: name,
					sets: [{
						name: "SetName",
						meshes: []
					}]
				});
				currentPresetName = name;
				currentSetName = "SetName";
				saveConfigMeshBatch();
				updateSelectPreset();
				onChangePreset();
				return;
			}
			currentPresetName = value;
			onChangePreset();
		});

		editPresetName.on("click", function() {
			if (currentPresetName == null) return;
			var preset = allSetGroups.filter(s -> s.name == currentPresetName);
			if (preset.length == 0) return;
			var name = hide.Ide.inst.ask("New name preset:");
			if (name == null || name.length == 0) return;
			preset[0].name = name;
			currentPresetName = name;
			saveConfigMeshBatch();
			updateSelectPreset();
			onChangePreset();
		});
		
		deletePreset.on("click", function() {
			if (currentPresetName == null) return;
			var preset = allSetGroups.filter(s -> s.name == currentPresetName);
			if (preset.length == 0) return;
			allSetGroups.remove(preset[0]);
			currentPresetName = null;
			currentSetName = null;
			saveConfigMeshBatch();
			updateSelectPreset();
			onChangePreset();
		});

		onChangePreset();

		var options = new hide.Element('<div class="btn-list" align="center" ></div>').appendTo(props);

		var selectAllBtn = new hide.Element('<input type="button" value="Select all" />').appendTo(options);
		var addBtn = new hide.Element('<input type="button" value="Add" >').appendTo(options);
		var removeBtn = new hide.Element('<input type="button" value="Remove" />').appendTo(options);
		var cleanBtn = new hide.Element('<input type="button" value="Remove all meshes" /><br />').appendTo(options);
		var repeatMeshBtn = new hide.Element('<input type="checkbox" style="margin-bottom: -5px;margin-right: 5px;" >Don\'t repeat same mesh in a row</input>').appendTo(options);
		new hide.Element('<br /><b><i>Hold down SHIFT to remove meshes</i></b>').appendTo(options);
		new hide.Element('<br /><b><i>Hold down R to random preview</i></b>').appendTo(options);

		repeatMeshBtn.on("change", function() {
			dontRepeatMesh = repeatMeshBtn.is(":checked");
		});
		repeatMeshBtn.prop("checked", dontRepeatMesh);

		selectAllBtn.on("click", function() {
			var options = selectElement.children().elements();
			for (opt in options) {
				opt.prop("selected", true);
			}
		});
		addBtn.on("click", function () {
			hide.Ide.inst.chooseFiles(["fbx", "l3d"], function(path) {
				for( m in path ) {
					addMeshPath(m);
					selectElement.append(new hide.Element('<option value="$m">${extractMeshName(m)}</option>'));
				}
			});
		});
		removeBtn.on("click", function () {
			var options = selectElement.children().elements();
			for (opt in options) {
				if (opt.prop("selected")) {
					removeMeshPath(opt.val());
					opt.remove();
				}
			}
		});
		cleanBtn.on("click", function() {
			if (hide.Ide.inst.confirm("Are you sure to remove all meshes for this MeshSpray ?")) {
				sceneEditor.deleteElements(children.copy());
				sceneEditor.selectObjects([this], Nothing);
			}
		});

		ectx.properties.add(props, this, function(pname) {});

		var optionsGroup = new hide.Element('<div class="group" name="Options"><dl></dl></div>');
		optionsGroup.append(hide.comp.PropsEditor.makePropsList([
				{ name: "density", t: PInt(1, 25), def: density },
				{ name: "densityOffset", t: PInt(0, 10), def: densityOffset },
				{ name: "radius", t: PFloat(0, 50), def: radius },
				{ name: "deleteRadius", t: PFloat(0, 50), def: deleteRadius },
				{ name: "scale", t: PFloat(0, 10), def: scale },
				{ name: "scaleOffset", t: PFloat(0, 1), def: scaleOffset },
				{ name: "rotation", t: PFloat(0, 180), def: rotation },
				{ name: "rotationOffset", t: PFloat(0, 30), def: rotationOffset }
			]));
		ectx.properties.add(optionsGroup, this, function(pname) {  });
	}

	override function setSelected( ctx : Context, b : Bool ) {
		if (timerCicle != null) {
			timerCicle.stop();
		}
		if( !b ) {
			if( interactive != null ) interactive.remove();
			timerCicle = new haxe.Timer(100);
			timerCicle.run = function() {
				timerCicle.stop();
				if( gBrushes != null ) {
					for (g in gBrushes) g.visible = false;
				}
				if (previewModels != null && previewModels.length > 0) {
					sceneEditor.deleteElements(previewModels, () -> { }, false, false);
					previewModels = [];
				}
				if (wasEdited)
					sceneEditor.refresh(Partial, () -> { });
				wasEdited = false;
			};
		}
		return false;
	}

	function addMeshPath(path : String) {
		var mesh = { path: path, isRef: path.indexOf(".fbx") == -1 };
		if (currentMeshes.filter(m -> m.path == path).length == 0)
			currentMeshes.push(mesh);
		if (currentSet != null)
			saveConfigMeshBatch();
	}

	function removeMeshPath(path : String) {
		var mesh = currentMeshes.filter(m -> m.path == path);
		if (mesh.length > 0)
			currentMeshes.remove(mesh[0]);
		if (currentSet != null)
			saveConfigMeshBatch();
	}

	var localMat = new h3d.Matrix();
	var lastPos : h3d.col.Point;
	var invParent : h3d.Matrix;
	var lastMeshId = -1;
	function previewMeshesAround(ctx : Context, point : h3d.col.Point) {
		if (currentMeshes.length == 0) {
			return;
		}
		if (invParent == null) {
			invParent = getTransform().clone();
			invParent.invert();
		}
		var nbMeshesInZone = 0;
		var vecRelat = point.toVector();
		var transform = this.getTransform().clone();
		transform.invert();
		vecRelat.transform3x4(transform);
		var point2d = new h2d.col.Point(vecRelat.x, vecRelat.y);

		var computedDensity = density + Std.random(densityOffset+1);

		var minDistanceBetweenMeshesSq = (radius * radius / computedDensity);

		var currentPivots : Array<h2d.col.Point> = [];
		inline function distance(x1 : Float, y1 : Float, x2 : Float, y2 : Float) return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
		var fakeRadius = radius * radius + minDistanceBetweenMeshesSq;
		for (child in children) {
			var model = child.to(hrt.prefab.Object3D);
			if (distance(point2d.x, point2d.y, model.x, model.y) < fakeRadius) {
				if (previewModels.indexOf(model) != -1) continue;
				nbMeshesInZone++;
				currentPivots.push(new h2d.col.Point(model.x, model.y));
			}
		}
		var nbMeshesToPlace = computedDensity - nbMeshesInZone;
		if (computedDensity == 1)
		if (previewModels.length > 0) {
			sceneEditor.deleteElements(previewModels, () -> { }, false);
			sceneEditor.selectObjects([this], Nothing);
			previewModels = [];
		}
		lastPos = point;
		if (nbMeshesToPlace > 0) {
			var random = new hxd.Rand(Std.random(0xFFFFFF));

			while (nbMeshesToPlace-- > 0) {
				var nbTry = 5;
				var position : h3d.col.Point;
				do {
					var randomRadius = radius*Math.sqrt(random.rand());
					var angle = random.rand() * 2*Math.PI;

					position = new h3d.col.Point(point.x + randomRadius*Math.cos(angle), point.y + randomRadius*Math.sin(angle), 0);
					var vecRelat = position.toVector();
					vecRelat.transform3x4(transform);

					var isNextTo = false;
					for (cPivot in currentPivots) {
						if (distance(vecRelat.x, vecRelat.y, cPivot.x, cPivot.y) <= minDistanceBetweenMeshesSq) {
							isNextTo = true;
							break;
						}
					}
					if (!isNextTo) {
						break;
					}
				} while (nbTry-- > 0);

				var randRotationOffset = random.rand() * rotationOffset;
				if (Std.random(2) == 0) {
					randRotationOffset *= -1;
				}
				var rotationZ = ((rotation  + randRotationOffset) % 360)/360 * 2*Math.PI;

				var meshId = 0;
				if(currentMeshes.length > 1) {
					do
						meshId = Std.random(currentMeshes.length)
					while(dontRepeatMesh && meshId == lastMeshId);
				}
				lastIndexMesh = meshId;
				if (computedDensity == 1)
					lastMeshId = meshId;
				else
					lastMeshId = -1;

				var meshUsed = currentMeshes[meshId];
				
				var newPrefab : hrt.prefab.Object3D = null;

				if (meshUsed.isRef) {
					var refPrefab = new hrt.prefab.Reference(this);
					refPrefab.refpath = "/"+meshUsed.path;
					newPrefab = refPrefab;
				} else {
					var model = new hrt.prefab.Model(this);
					model.source = meshUsed.path;
					newPrefab = model;
				}

				newPrefab.name = extractMeshName(meshUsed.path);

				localMat.initRotationZ(rotationZ);

				var randScaleOffset = random.rand() * scaleOffset;
				if (Std.random(2) == 0) {
					randScaleOffset *= -1;
				}
				var currentScale = (scale + randScaleOffset);

				localMat.scale(currentScale, currentScale, currentScale);

				position.z = getZ(position.x, position.y);
				localMat.setPosition(new Vector(position.x, position.y, position.z));
				localMat.multiply(localMat, invParent);

				newPrefab.setTransform(localMat);

				previewModels.push(newPrefab);
				currentPivots.push(new h2d.col.Point(newPrefab.x, newPrefab.y));
			}

			if (previewModels.length > 0) {
				sceneEditor.addObject(previewModels, false, false);
			}
		}
	}

	function addMeshes(ctx : Context) {
		lastMeshId = -1;
		if (previewModels.length > 0) {
			wasEdited = true;
			previewModels = [];
		}
	}

	function removeMeshesAround(ctx : Context, point : h3d.col.Point) {
		var vecRelat = point.toVector();
		var transform = this.getTransform().clone();
		transform.invert();
		vecRelat.transform3x4(transform);
		var point2d = new h2d.col.Point(vecRelat.x, vecRelat.y);

		var childToRemove = [];
		inline function distance(x1 : Float, y1 : Float, x2 : Float, y2 : Float) return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
		var fakeRadius = deleteRadius * deleteRadius;
		for (child in children) {
			var model = child.to(hrt.prefab.Object3D);
			if (distance(point2d.x, point2d.y, model.x, model.y) < fakeRadius) {
				childToRemove.push(child);
			}
		}
		if (childToRemove.length > 0) {
			wasEdited = true;
			sceneEditor.deleteElements(childToRemove, () -> { }, false);
			sceneEditor.selectObjects([this], Nothing);
		}
	}

	public function drawCircle(ctx : Context, originX : Float, originY : Float, originZ : Float, radius: Float, thickness: Float, color) {
		var newColor = h3d.Vector.fromColor(color);
		if (gBrushes == null || gBrushes.length == 0 || gBrushes[0].scaleX != radius || gBrushes[0].material.color != newColor) {
			if (gBrushes == null) gBrushes = [];
			for (g in gBrushes) g.remove();
			var gBrush = new h3d.scene.Mesh(makePrimCircle(32, 0.95), ctx.local3d);
			gBrush.scaleX = gBrush.scaleY = radius;
			gBrush.material.mainPass.setPassName("overlay");
			gBrush.material.shadows = false;
			gBrush.material.color = newColor;
			gBrushes.push(gBrush);
			gBrush = new h3d.scene.Mesh(new h3d.prim.Sphere(Math.min(radius*0.05, 0.35)), ctx.local3d);
			gBrush.material.mainPass.setPassName("overlay");
			gBrush.material.shadows = false;
			gBrush.material.color = newColor;
			gBrushes.push(gBrush);
		}
		for (g in gBrushes) g.visible = true;
		for (g in gBrushes) {
			g.x = originX;
			g.y = originY;
			g.z = originZ + 0.025;
		}
	}

	function makePrimCircle(segments: Int, inner : Float = 0, rings : Int = 0) {
		var points = [];
		var uvs = [];
		var indices = [];
		++segments;
		var anglerad = hxd.Math.degToRad(360);
		for(i in 0...segments) {
			var t = i / (segments - 1);
			var a = hxd.Math.lerp(-anglerad/2, anglerad/2, t);
			var ct = hxd.Math.cos(a);
			var st = hxd.Math.sin(a);
			for(r in 0...(rings + 2)) {
				var v = r / (rings + 1);
				var r = hxd.Math.lerp(inner, 1.0, v);
				points.push(new h2d.col.Point(ct * r, st * r));
				uvs.push(new h2d.col.Point(t, v));
			}
		}
		for(i in 0...segments-1) {
			for(r in 0...(rings + 1)) {
				var idx = r + i * (rings + 2);
				var nxt = r + (i + 1) * (rings + 2);
				indices.push(idx);
				indices.push(idx + 1);
				indices.push(nxt);
				indices.push(nxt);
				indices.push(idx + 1);
				indices.push(nxt + 1);
			}
		}

		var verts = [for(p in points) new h3d.col.Point(p.x, p.y, 0.)];
		var idx = new hxd.IndexBuffer();
		for(i in indices)
			idx.push(i);
		var primitive = new h3d.prim.Polygon(verts, idx);
		primitive.normals = [for(p in points) new h3d.col.Point(0, 0, 1.)];
		primitive.tangents = [for(p in points) new h3d.col.Point(0., 1., 0.)];
		primitive.uvs = [for(uv in uvs) new h3d.prim.UV(uv.x, uv.y)];
		primitive.colors = [for(p in points) new h3d.col.Point(1,1,1)];
		primitive.incref();
		return primitive;
	}

	var terrainPrefab : hrt.prefab.terrain.Terrain = null;

	// GET Z with TERRAIN
	public function getZ( x : Float, y : Float ) {
		var z = this.z;

		if (terrainPrefab == null)
			@:privateAccess terrainPrefab = sceneEditor.sceneData.find(p -> Std.downcast(p, hrt.prefab.terrain.Terrain));

		if(terrainPrefab != null){
			var pos = new h3d.Vector(x, y, 0);
			pos.transform3x4(this.getTransform());
			z = terrainPrefab.terrain.getHeight(pos.x, pos.y);
		}

		return z;
	}

	public function  getMousePicker( ?x, ?y ) {
		var camera = sceneEditor.scene.s3d.camera;
		var ray = camera.rayFromScreen(x, y);
		var planePt = ray.intersect(h3d.col.Plane.Z());
		var offset = ray.getDir();

		// Find rough intersection point in the camera forward direction to get first collision point
		final maxZBounds = 25;
		offset.scale(maxZBounds);
		var pt = planePt.clone();
		pt.load(pt.sub(offset));

		var step = ray.getDir();
		step.scale(0.25);

		while(pt.z > -maxZBounds) {
			var z = getZ(pt.x, pt.y);
			if(pt.z < z)
				break;
			pt.load(pt.add(step));
		}

		// Bissect search for exact intersection point
		for(_ in 0...50) {
			var z = getZ(pt.x, pt.y);
			var delta = z - pt.z;
			if(hxd.Math.abs(delta) < 0.05)
				return pt;

			if(delta < 0)
				pt.load(pt.add(step));
			else
				pt.load(pt.sub(step));

			step.scale(0.5);
		}

		return planePt;
	}


	public function screenToWorld(sx: Float, sy: Float) {
		var camera = sceneEditor.scene.s3d.camera;
		var ray = camera.rayFromScreen(sx, sy);
		var dist = projectToGround(ray);
		if(dist >= 0) {
			return ray.getPoint(dist);
		}
		return null;
	}

	function projectToGround( ray: h3d.col.Ray ) {
		var dist = 0.0;
		if (terrainPrefab == null)
			@:privateAccess terrainPrefab = sceneEditor.sceneData.find(p -> Std.downcast(p, hrt.prefab.terrain.Terrain));

		if (terrainPrefab != null) {
			var normal = terrainPrefab.terrain.getAbsPos().up();
			var plane = h3d.col.Plane.fromNormalPoint(normal.toPoint(), new h3d.col.Point(terrainPrefab.terrain.getAbsPos().tx, terrainPrefab.terrain.getAbsPos().ty, terrainPrefab.terrain.getAbsPos().tz));
			var pt = ray.intersect(plane);
			if(pt != null) { dist = pt.sub(ray.getPos()).length();}
		}
		return dist;
	}

	#end

	static var _ = Library.register("meshSpray", MeshSpray);
}