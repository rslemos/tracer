/*******************************************************************************
 * BEGIN COPYRIGHT NOTICE
 * 
 * This file is part of program "Tracer"
 * Copyright 2008  Rodrigo Lemos
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * END COPYRIGHT NOTICE
 ******************************************************************************/
package br.eti.rslemos.tracer;

import java.lang.reflect.Array;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.LinkedList;

import org.aspectj.lang.reflect.MethodSignature;
import org.aspectj.lang.reflect.SourceLocation;

public abstract aspect Tracer {
	private final int INDENT_SIZE = 4;
	
	private int indent = -INDENT_SIZE;

	private int modCount = 0;
	
	private LinkedList<Integer> stack = new LinkedList<Integer>();
	
	
	protected abstract pointcut filter();
	
	private pointcut methodcall(): call(* *(..));
	private pointcut ctorcall(): call(*.new(..));
	
	private pointcut setter(Object value): set(* *) && args(value) && filter();
	
	private pointcut cflowTracer(): cflow(within(Tracer+));

	private pointcut tracemethod(): methodcall() && !cflowTracer() && filter();
	
	private pointcut tracector(): ctorcall() && !cflowTracer() && filter();
	
	private pointcut tracecall(): tracector() || tracemethod();

	private pointcut traceset(Object value): setter(value) && !cflowTracer() && filter();

	before(): tracecall() || traceset(Object) {
		stack.push(++modCount);
		indent += INDENT_SIZE;
	}
	
	before(Object value): traceset(value) {
		String message = thisJoinPointStaticPart.getSignature().toString() + " = " + toString(value);
		fieldSet(thisJoinPointStaticPart.getSourceLocation(), message);
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
		
		entry(location, signature + "(" + builder.toString() + ") ");
	}
	
	after() returning(Object result): tracemethod() {
		MethodSignature methodSignature = (MethodSignature)thisJoinPointStaticPart.getSignature();
		if (methodSignature.getReturnType() != Void.TYPE) {
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
			System.out.printf("\n[% 8d] %40s << %s%s", modCount, "[" + stack.getFirst() + "]", getIndentString(), message);
	}
	
	private void abnormalExit(String message) {
		if (stack.getFirst() == modCount)
			System.out.print("!! " + message);
		else
			System.out.printf("\n[% 8d] %40s !! %s%s", modCount, "[" + stack.getFirst() + "]", getIndentString(), message);
	}
	
	private void entry(SourceLocation sl, String message) {
		System.out.printf("\n[% 8d] %40s >> %s%s", modCount, "(" + sl.toString() + ")", getIndentString(), message);
	}

	private void fieldSet(SourceLocation sl, String message) {
		System.out.printf("\n[% 8d] %40s == %s%s", modCount, "(" + sl.toString() + ")", getIndentString(), message);
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
			if (!clazz.isArray()) {
				try {
					Method toString = clazz.getMethod("toString", new Class[0]);
					Method toString0 = Object.class.getMethod("toString", new Class[0]);
					
					if (toString0.equals(toString))
						return "<" + clazz.getSimpleName() + ">";
					
				} catch (NoSuchMethodException e) {
				}
			} else {
				int length = Array.getLength(o);
				StringBuilder builder = new StringBuilder();
				builder.append("[");
				
				for(int i = 0; i < length && i < 3; i++) {
					builder.append(toString(Array.get(o, i)));
					builder.append(", ");
				}
				if (length > 3)
					builder.append("... more ").append(length - 3).append(" elements");
				else
					builder.setLength(builder.length() - 2);
				
				builder.append("]");
				return builder.toString();
			}
		}
		
		return String.valueOf(o);
	}
}
