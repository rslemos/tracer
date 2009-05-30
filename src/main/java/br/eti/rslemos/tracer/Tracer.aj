package br.eti.rslemos.tracer;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;

import org.aspectj.lang.reflect.MethodSignature;
import org.aspectj.lang.reflect.SourceLocation;

public aspect Tracer {
	private final int INDENT_SIZE = 4;
	
	private int indent = -INDENT_SIZE;

	private pointcut methodcall(): call(* *(..));
	private pointcut ctorcall(): call(*.new(..));
	
	private pointcut setter(Object value): set(* *) && args(value);
	
	private pointcut cflowJavaUtil(): cflow(call(* java.util.*.*(..)));
	
	private pointcut cflowJavaLang(): cflow(call(* java.lang.*.*(..)));
	
	private pointcut tracemethod(): methodcall() && !cflowJavaUtil() && !cflowJavaLang() && !within(Tracer+);
	
	private pointcut tracector(): ctorcall() && !cflowJavaUtil() && !cflowJavaLang() && !within(Tracer+);
	
	private pointcut tracecall(): tracector() || tracemethod();

	private pointcut traceset(Object value): setter(value) && !cflowJavaUtil() && !cflowJavaLang() && !within(Tracer+);

	before(Object value): traceset(value) {
		String message = thisJoinPointStaticPart.getSignature().toString() + " = " + String.valueOf(value) + " (" + thisJoinPointStaticPart.getSourceLocation() + ")";
		printOnNewLine(1, message);
	}
	
	before(): tracecall() {
		increaseIndent();
	}
	
	before(): tracemethod() {
		MethodSignature methodSignature = (MethodSignature)thisJoinPointStaticPart.getSignature();
		String signature = methodSignature.getReturnType().getSimpleName() + " " + methodSignature.getDeclaringTypeName() + "." + methodSignature.getName();
		traceCall(thisJoinPointStaticPart.getSourceLocation(), signature, thisJoinPoint.getArgs());
	}
	
	before(): tracector() {
		String signature = "new " + thisJoinPointStaticPart.getSignature().getDeclaringTypeName();

		traceCall(thisJoinPointStaticPart.getSourceLocation(), signature, thisJoinPoint.getArgs());
	}
	
	private void traceCall(SourceLocation location, String signature, Object[] args) {
		StringBuilder builder = new StringBuilder();
		for (Object arg : args)
			builder.append(toString(arg)).append(", ");
		
		if (builder.length() > 0)
			builder.setLength(builder.length() - 2);
		
		printOnNewLine(0, signature + "(" + builder.toString() + ")" + " (" + location + ") ");
	}
	
	after() returning(Object result): tracemethod() {
		MethodSignature methodSignature = (MethodSignature)thisJoinPointStaticPart.getSignature();
		if (methodSignature.getReturnType() != void.class) {
			printOnNewLine(0, "..." + toString(result));
		} 
	}
	
	after() returning(Object result): tracector() {
		printOnNewLine(0, "..." + toString(result));
	}
	
	after() throwing(Throwable t): tracecall() {
		printOnNewLine(0, "...threw " + t.getClass().getName() + ": \"" + t.getMessage() + "\"");
	}
	
	after(): tracecall() {
		decreaseIndent();
	}
	
	private void printOnNewLine(int extra, String message) {
		System.out.print("\n" + getIndentString(extra) + message);
	}

	private String getIndentString(int extra) {
		char[] c = new char[indent + extra*INDENT_SIZE];
		Arrays.fill(c, ' ');
		
		return new String(c);
	}

	private void increaseIndent() {
		indent += INDENT_SIZE;
	}

	private void decreaseIndent() {
		indent -= INDENT_SIZE;
	}

	private String toString(Object o) {
		if (o instanceof String)
			return "\"" + o + "\"";
		else if (o != null) {
			Class<?> clazz = o.getClass();
			try {
				Method toString = clazz.getMethod("toString", new Class[0]);
				Method toString0 = Object.class.getMethod("toString", new Class[0]);
				
				if (toString0.equals(toString))
					return clazz.getSimpleName() + "@" + Integer.toHexString(System.identityHashCode(o));
				
			} catch (NoSuchMethodException e) {
			}
		}
		
		return String.valueOf(o);
	}
}
