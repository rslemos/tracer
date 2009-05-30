package br.eti.rslemos.tracer;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;

import org.aspectj.lang.Signature;
import org.aspectj.lang.reflect.ConstructorSignature;
import org.aspectj.lang.reflect.MethodSignature;

public aspect Tracer {
	private final int INDENT_SIZE = 4;
	
	private int indent = -INDENT_SIZE;

	private pointcut methodcall(): call(* *(..));
	private pointcut ctorcall(): call(*.new(..));
	
	private pointcut setter(Object value): set(* *) && args(value);
	
	private pointcut cflowJavaUtil(): cflow(call(* java.util.*.*(..)));
	
	private pointcut cflowJavaLang(): cflow(call(* java.lang.*.*(..)));
	
	private pointcut tracecall(): (methodcall() || ctorcall()) && !cflowJavaUtil() && !cflowJavaLang() && !within(Tracer+);

	private pointcut traceset(Object value): setter(value) && !cflowJavaUtil() && !cflowJavaLang() && !within(Tracer+);

	before(Object value): traceset(value) {
		String message = thisJoinPointStaticPart.getSignature().toString() + " = " + String.valueOf(value) + " (" + thisJoinPointStaticPart.getSourceLocation() + ")";
		printOnNewLine(INDENT_SIZE, message);
	}
	
	before(): tracecall() {
		Signature aspectSignature = thisJoinPointStaticPart.getSignature();

		List<Object> args = Arrays.asList(thisJoinPoint.getArgs());
		
		String argsStr = args.toString();
		argsStr = argsStr.substring(1, argsStr.length() - 1);
		
		String signature;

		if (aspectSignature instanceof MethodSignature) {
			MethodSignature methodSignature = (MethodSignature)aspectSignature;
			signature = methodSignature.getReturnType().getSimpleName() + " " + methodSignature.getDeclaringTypeName() + "." + methodSignature.getName();
		} else if (aspectSignature instanceof ConstructorSignature) {
			signature = "new " + aspectSignature.getDeclaringTypeName();
		} else
			signature = aspectSignature.getDeclaringTypeName() + "." + aspectSignature.getName();
		
		indent += INDENT_SIZE;

		printOnNewLine(0, signature + "(" + argsStr + ")" + " (" + thisJoinPointStaticPart.getSourceLocation() + ") ");
	}
	
	after() returning(Object result): tracecall() {
		Signature aspectSignature = thisJoinPointStaticPart.getSignature();

		String resultStr;
		if (aspectSignature instanceof MethodSignature) {
			MethodSignature methodSignature = (MethodSignature)aspectSignature;
			if (methodSignature.getReturnType() == void.class)
				resultStr = null;
			else if (result instanceof String)
				resultStr = "\"" + result + "\"";
			else
				resultStr = String.valueOf(result);
		} else if (aspectSignature instanceof ConstructorSignature) {
			if (result instanceof String)
				resultStr = "\"" + result + "\"";
			else if (result != null) {
				Class<?> clazz = result.getClass();
				try {
					Method toString = clazz.getMethod("toString", new Class[0]);
					Method toString0 = Object.class.getMethod("toString", new Class[0]);
					
					if (toString0.equals(toString)) {
						resultStr = String.valueOf(System.identityHashCode(result));
					} else
						resultStr = String.valueOf(result);
				} catch (NoSuchMethodException e) {
					resultStr = String.valueOf(result);
				}
			} else
				resultStr = String.valueOf(result);
		} else
			resultStr = String.valueOf(result);

		if (resultStr != null) {
			printOnNewLine(0, "..." + resultStr);
		}
		
		indent -= INDENT_SIZE;
	}
	
	after() throwing(Throwable t): tracecall() {
		printOnNewLine(0, "...threw " + t.getClass().getName() + ": \"" + t.getMessage() + "\"");

		indent -= INDENT_SIZE;
	}
	
	private void printOnNewLine(int offset, String message) {
		System.out.print("\n" + getIndentString(offset) + message);
	}

	private String getIndentString(int offset) {
		char[] c = new char[indent + offset];
		Arrays.fill(c, ' ');
		
		return new String(c);
	}

}
