package aerys.minko.query.rendering
{
	import aerys.minko.Viewport3D;
	import aerys.minko.effect.Effect3DStyleStack;
	import aerys.minko.effect.IEffect3D;
	import aerys.minko.effect.IEffect3DPass;
	import aerys.minko.effect.IStyled3D;
	import aerys.minko.ns.minko;
	import aerys.minko.query.IScene3DQuery;
	import aerys.minko.render.IRenderer3D;
	import aerys.minko.render.state.RenderState;
	import aerys.minko.scene.IScene3D;
	import aerys.minko.scene.camera.ICamera3D;
	import aerys.minko.type.stream.IndexStream3D;
	import aerys.minko.type.stream.VertexStream3DList;
	
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.textures.TextureBase;
	
	public class RenderingQuery implements IScene3DQuery
	{
		use namespace minko;
		
		private var _renderer	: IRenderer3D			= null;
		
		private var _current	: IScene3D				= null;
		private var _parent		: IScene3D				= null;
		private var _parents	: Vector.<IScene3D>		= new Vector.<IScene3D>();
		private var _camera		: ICamera3D				= null;
		private var _styleStack	: Effect3DStyleStack	= new Effect3DStyleStack();
		private var _tm			: TransformManager		= new TransformManager();
		private var _fx			: Vector.<IEffect3D>	= new Vector.<IEffect3D>();
		private var _numNodes	: uint					= 0;
		
		public function get parent()		: IScene3D				{ return _parent; }
		public function get camera()		: ICamera3D				{ return _camera; }
		public function get style()			: Effect3DStyleStack	{ return _styleStack; }
		public function get transform()		: TransformManager		{ return _tm; }
		public function get viewport()		: Viewport3D			{ return _renderer.viewport; }
		public function get numTriangles()	: uint					{ return _renderer.numTriangles; }
		public function get drawingTime()	: int					{ return _renderer.drawingTime; }
		public function get frameId()		: uint					{ return _renderer.frameId; }
		public function get effects()		: Vector.<IEffect3D>	{ return _fx; }
		public function get numNodes()		: uint					{ return _numNodes; }
		
		public function set style(value : Effect3DStyleStack) : void
		{
			_styleStack = value;
		}
		
		public function set effects(value : Vector.<IEffect3D>) : void
		{
			_fx = value;
		}
		
		public function RenderingQuery(renderer : IRenderer3D)
		{
			_renderer = renderer;
		}
		
		public function query(scene : IScene3D) : void
		{
			var numParents : int = _parents.length;
			
			_parents[numParents] = _parent;
			_parent = _current;
			_current = scene;
			
			++_numNodes;
			
			var camera : ICamera3D = scene as ICamera3D;
			
			if (camera && camera.enabled)
			{
				if (_camera)
					throw new Error();
				
				_camera = camera;
			}
			
			scene.accept(this);
			
			_current = _parent;
			_parent = _parents[numParents];
			_parents.length = numParents;
		}
		
		public function reset() : void
		{
			_camera = null;
			_parents.length = 0;
			_numNodes = 0;
			_renderer.clear();
			_tm.reset();
//			_style.clear();
			
			if (_fx.length != 0)
				throw new Error('Effect3DList stack should be empty.');
		}
		
		public function draw(vertexStreamList 	: VertexStream3DList,
							 indexStream 		: IndexStream3D,
							 offset				: uint	= 0,
							 numTriangles		: uint	= 0) : void
		{
			var numEffects 	: int 					= _fx.length;
			
			if (numEffects == 0)
				throw new Error("Unable to draw without an effect.");
			
			for (var i : int = 0; i < numEffects; ++i)
			{
				var fx			: IEffect3D					= _fx[i];
				var passes		: Vector.<IEffect3DPass>	= fx.currentTechnique.passes;
				var numPasses 	: int 						= passes.length;
				
				//_style = fx.style.override(_style);
				_styleStack.push(fx.style);
				fx.begin(_renderer, _styleStack);
				
				for (var j : int = 0; j < numPasses; ++j)
				{
					var pass : IEffect3DPass = passes[j];
					
					_renderer.begin();
					if (pass.begin(_renderer, _styleStack))
					{
						var state:RenderState = _renderer.state;
						
						state.setInputStreams(vertexStreamList, indexStream);
						_renderer.drawTriangles(offset, numTriangles);
					}
					
					pass.end(_renderer, _styleStack);
					_renderer.end();
				}
				
				fx.end(_renderer, _styleStack);
				//_style = fx.style.override();
				_styleStack.pop();
			}
		}
		
		public function drawList(vertexStreamList 	: VertexStream3DList,
								 indexStream 		: IndexStream3D,
								 offsets			: Vector.<uint>,
								 numTriangles		: Vector.<uint> = null) : void
		{
			var numEffects 	: int 	= _fx.length;
			
			if (numEffects == 0)
				throw new Error("Unable to draw without an effect.");
			
			var length	: int			= offsets.length;
			
			if (length != numTriangles.length)
				throw new Error();
			
			for (var i : int = 0; i < numEffects; ++i)
			{
				var fx			: IEffect3D					= _fx[i];
				var passes		: Vector.<IEffect3DPass>	= fx.currentTechnique.passes;
				var numPasses 	: int 						= passes.length;
				
				//_style = fx.style.override(_style);
				_styleStack.push(fx.style);
				fx.begin(_renderer, _styleStack);
				
				for (var j : int = 0; j < numPasses; ++j)
				{
					var pass : IEffect3DPass = passes[j];
					
					_renderer.begin();
					if (pass.begin(_renderer, _styleStack))
					{
						var state	: RenderState 	= _renderer.state;
						
						state.setInputStreams(vertexStreamList, indexStream);
						for (var k : int = 0; k < length; k += 1)
							_renderer.drawTriangles(offsets[k], numTriangles[k]);
					}
					
					_renderer.end();
					pass.end(_renderer, _styleStack);
				}
				
				fx.end(_renderer, _styleStack);
				//_style = fx.style.override();
				_styleStack.pop();
			}
		}
		
		public function createTexture(width 		: uint,
									  height 		: uint,
									  format 		: String	= Context3DTextureFormat.BGRA,
									  renderTarget	: Boolean 	= false) : TextureBase
		{
			return _renderer.createTexture(width, height, format, renderTarget);
		}
	}
}