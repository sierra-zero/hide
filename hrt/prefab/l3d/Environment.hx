package hrt.prefab.l3d;


@:access(h3d.scene.pbr.Environment)
class Environment extends Object3D {

	var sourceMapPath : String;
	var configName : String;
	var env : h3d.scene.pbr.Environment;

	public var power : Float = 1.0;
	public var hdrMax : Float = 10.0;
	public var rotation : Float = 0.0;
	public var sampleBits : Int = 12;
	public var diffSize : Int = 64;
	public var specSize : Int = 512;
	public var ignoredSpecLevels : Int = 1;

	public function new( ?parent ) {
		super(parent);
		type = "environment";
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
	 	power = obj.power != null ? obj.power : 1.0;
		hdrMax = obj.hdrMax != null ? obj.hdrMax : 10.0;
		rotation = obj.rotation != null ? obj.rotation : 0.0;
		sampleBits = obj.sampleBits != null ? obj.sampleBits : 12;
		diffSize = obj.diffSize != null ? obj.diffSize : 64;
		specSize = obj.specSize != null ? obj.specSize : 512;
		ignoredSpecLevels = obj.ignoredSpecLevels != null ? obj.ignoredSpecLevels : 1;
		sourceMapPath = obj.sourceMapPath != null ? obj.sourceMapPath : null;
		configName = obj.configName;
	}

	override function save() {
		var obj : Dynamic = super.save();
		obj.power = power;
		obj.rotation = rotation;
		obj.sampleBits = sampleBits;
		obj.diffSize = diffSize;
		obj.specSize = specSize;
		obj.ignoredSpecLevels = ignoredSpecLevels;
		obj.sourceMapPath = sourceMapPath;
		obj.hdrMax = hdrMax;
		if( configName != null ) obj.configName = configName;
		return obj;
	}

	function loadFromBinary() {
		try {
			env.dispose();
			env.diffuse = hxd.res.Loader.currentInstance.load(getBinaryPath(true)).toImage().toTexture();
			env.specular = hxd.res.Loader.currentInstance.load(getBinaryPath(false)).toImage().toTexture();
			env.specular.mipMap = Linear;
			env.specLevels = env.getMipLevels() - ignoredSpecLevels;
			return true;
		} catch( e : hxd.res.NotFound ) {
			return false;
		}
	}

	function getBinaryPath( diffuse : Bool ) {
		var path = new haxe.io.Path(sourceMapPath);
		if( configName != null )
			path.file += "-" + configName;
		path.ext = diffuse ? "envd.dds" : "envs.dds";
		return path.toString();
	}

	function saveToBinary() {
		#if (hl || hxnodejs)
		var fs = cast(hxd.res.Loader.currentInstance.fs, hxd.fs.LocalFileSystem);
		if( fs == null ) return;
		var diffuse = hxd.Pixels.toDDS([for( i in 0...6 ) env.diffuse.capturePixels(i)],true);
		sys.io.File.saveBytes(fs.baseDir + getBinaryPath(true), diffuse);
		var specular = hxd.Pixels.toDDS([for( i in 0...6 ) for( mip in 0...env.getMipLevels() ) env.specular.capturePixels(i,mip)],true);
		sys.io.File.saveBytes(fs.baseDir + getBinaryPath(false), specular);
		#end
	}

	override function makeInstance( ctx : Context ) : Context {
		super.makeInstance(ctx);
		updateInstance(ctx);
		return ctx;
	}

	override function updateInstance( ctx : Context, ?propName : String ) {
		super.updateInstance(ctx, propName);

		var sourceMap = sourceMapPath != null ? ctx.loadTexture(sourceMapPath) : null;
		if( sourceMap == null )
			return;

		#if editor
		if( sourceMap.flags.has(Loading) ) {
			haxe.Timer.delay(function() {
				ctx.setCurrent();
				if( h3d.Engine.getCurrent().driver == null ) return; // was disposed
				updateInstance(ctx,propName);
			},100);
			return;
		}
		#end

		var needLoad = false;
		if( env == null )
			env = new h3d.scene.pbr.Environment(null);

		if( configName != null ) {
			configName = StringTools.trim(configName);
			if( configName == "" ) configName = null;
		}

		if( env.source != sourceMap ) {
			env.source = sourceMap;
			needLoad = true;
		}

		env.specSize = specSize;
		env.diffSize = diffSize;
		env.sampleBits = sampleBits;
		env.ignoredSpecLevels = ignoredSpecLevels;
		env.hdrMax = hdrMax;

		env.rot = rotation;
		env.power = power;

		if( propName == "force" || (needLoad && !loadFromBinary()) ) {
			env.dispose();
			env.specular = null;
			env.diffuse = null;
			env.compute();
			saveToBinary();
		}

		var scene = ctx.local3d.getScene();
		// Auto Apply on change
		if( scene != null )
			applyToRenderer(scene.renderer);
	}

	public function applyToRenderer( r : h3d.scene.Renderer) {
		var r = Std.downcast(r, h3d.scene.pbr.Renderer);
		if( r != null )
			r.env = env;
	}

	#if editor

	override function getHideProps() : HideProps {
		return { icon : "sun-o", name : "Environment" };
	}

	override function edit( ctx : EditContext ) {
		// super.edit(ctx);

		var props = new hide.Element('
			<div class="group" name="Environment">
				<div align="center" >
					<input type="button" value="Set Current" class="apply" />
				</div>
				<dl>
					<dt>SkyBox</dt><dd><input type="texturepath" field="sourceMapPath"/></dd>
					<dt>Rotation</dt><dd><input type="range" min="0" max="360" field="rotation"/></dd>
					<dt>Power</dt><dd><input type="range" min="0" max="2" field="power"/></dd>
				</dl>
			</div>
			<div class="group closed" name="Generation">
				<dl>
					<dt>Diffuse</dt><dd><input type="range" min="1" max="512" step="1" field="diffSize"/></dd>
					<dt>Specular</dt><dd><input type="range" min="1" max="2048" step="1" field="specSize"/></dd>
					<dt>Sample Count</dt><dd><input type="range" min="1" max="12" step="1" field="sampleBits"/></dd>
					<dt>Ignored Spec Levels</dt><dd><input type="range" min="0" max="3" step="1" field="ignoredSpecLevels"/></dd>
					<dt>HDR Max</dt><dd><input type="range" min="0" max="100" field="hdrMax"/></dd>
					<dt>Config Name</dt><dd><input type="text" field="configName"/></dd>
					<dt>&nbsp;</dt><dd><input type="button" class="compute" value="Compute"/></dd>
					<dt>View</dt><dd>
						<input type="button" style="width:90px" class="showDif" value="Diffuse"/>
						<input type="button" style="width:90px" class="showSpec" value="Specular"/>
					</dd>
				</dl>
			</div>
		');

		var applyButton = props.find(".apply");
		applyButton.click(function(_) {
			applyToRenderer(ctx.rootContext.local3d.getScene().renderer);
		});

		props.find(".compute").click(function(_) {
			ctx.onChange(this,"force");
		});

		props.find(".showDif").click(function(_) {
			ctx.ide.openFile(getBinaryPath(true));
		});

		props.find(".showSpec").click(function(_) {
			ctx.ide.openFile(getBinaryPath(false));
		});

		ctx.properties.add(props, this, function(pname) {
			ctx.onChange(this, pname);
		});
	}

	#end

	static var _ = Library.register("environment", Environment);
}