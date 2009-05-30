package br.eti.rslemos.tracer;

public aspect RslemosTracer extends Tracer {
	protected pointcut filter(): within(br.eti.rslemos.*.*);
}
