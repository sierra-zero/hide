package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Dot")
@description("The output is the dot product of a and b")
@width(80)
@group("Math")
class Dot extends ShaderFunction {

	@input("a") var a = SType.Number;
	@input("b") var b = SType.Number;

	public function new() {
		super(Dot);
	}

	override public function computeOutputs() {
		addOutput("output", TFloat);
	}
}