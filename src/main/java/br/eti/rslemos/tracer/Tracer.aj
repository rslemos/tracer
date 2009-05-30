package br.eti.rslemos.tracer;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.LinkedList;

import org.aspectj.lang.reflect.MethodSignature;
import org.aspectj.lang.reflect.SourceLocation;

public abstract aspect Tracer {
	private final long START_TIME = System.currentTimeMillis();
	
	private final int INDENT_SIZE = 4;
	
	private int indent = -INDENT_SIZE;

	private int modCount = 0;
	
	private LinkedList<Integer> stack = new LinkedList<Integer>();
	
	
	protected abstract pointcut filter();
	
	private pointcut methodcall(): call(* *(..));
	private pointcut ctorcall(): call(*.new(..));
	
	private pointcut setter(Object value): set(* *) && args(value) && filter();
	
	private pointcut cflowJavaUtil(): cflow(execution(* java.util.*.*(..)));
	
	private pointcut cflowJavaLang(): cflow(execution(* java.lang.*.*(..)));

	private pointcut cflowTracer(): cflow(within(Tracer+));

	private pointcut tracemethod(): methodcall() && !cflowJavaUtil() && !cflowJavaLang() && !cflowTracer() && filter();
	
	private pointcut tracector(): ctorcall() && !cflowJavaUtil() && !cflowJavaLang() && !cflowTracer() && filter();
	
	private pointcut tracecall(): tracector() || tracemethod();

	private pointcut traceset(Object value): setter(value) && !cflowJavaUtil() && !cflowJavaLang() && !cflowTracer() && filter();

	before(): tracecall() || traceset(Object) {
		stack.push(++modCount);
		indent += INDENT_SIZE;
	}
	
	before(Object value): traceset(value) {
		String message = thisJoinPointStaticPart.getSignature().toString() + " = " + toString(value) + " (" + thisJoinPointStaticPart.getSourceLocation() + ")";
		fieldSet(message);
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
		
		entry(signature + "(" + builder.toString() + ")" + " (" + location + ") ");
	}
	
	after() returning(Object result): tracemethod() {
		MethodSignature methodSignature = (MethodSignature)thisJoinPointStaticPart.getSignature();
		if (methodSignature.getReturnType() != void.class) {
			normalExit(toString(result));
		} 
	}
	
	after() returning(Object result): tracector() {
		normalExit(toString(result));
	}

	after() throwing(Throwable t): tracecall() {
		abnormalExit("threw " + t.getClass().getName() + ": \"" + t.getMessage() + "\"");
	}
	
	after(): tracecall() || traceset(Object) {
		indent -= INDENT_SIZE;
		stack.pop();
	}
	
	private void normalExit(String message) {
		if (stack.getFirst() == modCount)
			System.out.print("<< " + message);
		else
			System.out.printf("\n[% 8d] << %s%s", System.currentTimeMillis() - START_TIME, getIndentString(), message);
	}
	
	private void abnormalExit(String message) {
		if (stack.getFirst() == modCount)
			System.out.print("!! " + message);
		else
			System.out.printf("\n[% 8d] !! %s%s", System.currentTimeMillis() - START_TIME, getIndentString(), message);
	}
	
	private void entry(String message) {
		System.out.printf("\n[% 8d] >> %s%s", System.currentTimeMillis() - START_TIME, getIndentString(), message);
	}

	private void fieldSet(String message) {
		System.out.printf("\n[% 8d] == %s%s", System.currentTimeMillis() - START_TIME, getIndentString(), message);
	}

	private String getIndentString() {
		char[] c = new char[indent];
		Arrays.fill(c, ' ');
		
		return new String(c);
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
					return "<" + clazz.getSimpleName() + ">";
				
			} catch (NoSuchMethodException e) {
			}
		}
		
		return String.valueOf(o);
	}
}
