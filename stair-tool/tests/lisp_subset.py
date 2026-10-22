"""Small evaluator for pure list/number helpers; not an AutoCAD emulator.

COM, dialogs, drawing changes and Excel access deliberately cannot run here.
AutoLISP LAST returns the final element, unlike Common Lisp LAST.
"""
from collections import ChainMap
from math import dist
from test_standards import Symbol


def truth(value):
    return value is not None and value is not False and value != []


class PureLisp:
    def __init__(self, forms):
        self.defs = {f[1]: f for f in forms if isinstance(f, list) and f and f[0] == 'defun'}
        self.host = {
            '+': lambda *xs: sum(xs), '-': lambda a, *xs: a - sum(xs),
            '*': lambda a, b: a * b, '/': lambda a, b: a / b,
            '<': lambda a, b: a < b, '>': lambda a, b: a > b,
            '>=': lambda a, b: a >= b, '=': lambda a, b: a == b,
            '<=': lambda a, b: a <= b, '/=': lambda a, b: a != b,
            'not': lambda v: not truth(v), 'numberp': lambda v: isinstance(v, (int, float)),
            'abs': abs, 'null': lambda v: not truth(v), 'length': lambda v: len(v or []),
            'min': min, 'max': max, 'nth': lambda i, v: v[i] if i < len(v) else None,
            'car': lambda v: v[0] if v else None, 'cdr': lambda v: v[1:] if v else None,
            'cadr': lambda v: v[1], 'caar': lambda v: v[0][0],
            'cadar': lambda v: v[0][1], 'last': lambda v: v[-1] if v else None,
            'cons': lambda head, tail: [head] + (tail or []), 'list': lambda *xs: list(xs),
            'append': lambda a, b: (a or []) + (b or []),
            'reverse': lambda v: list(reversed(v or [])), 'distance': dist,
            'strlen': len, 'strcat': lambda *s: ''.join(s),
            'substr': lambda s, start, length=None: s[start-1:] if length is None else s[start-1:start-1+length],
            'vl-string-search': lambda part, s: s.index(part) if part in s else None,
        }
        self.host['mapcar'] = lambda fn, values: [self.call(fn, v) for v in values]
        self.host['apply'] = lambda fn, values: self.call(fn, *values)

    def call(self, name, *args):
        return self.invoke(name, args, ChainMap({}))

    def invoke(self, name, args, env):
        if name in self.host:
            return self.host[name](*args)
        form = self.defs[name]
        spec = form[2]
        split = spec.index('/') if '/' in spec else len(spec)
        params = spec[:split]
        if len(args) != len(params):
            raise ValueError(f'{name}: wrong argument count')
        local = dict.fromkeys(spec[split+1:])
        local.update(zip(params, args))
        return self.body(form[3:], env.new_child(local))

    def body(self, forms, env):
        result = None
        for form in forms:
            result = self.eval(form, env)
        return result

    def eval(self, form, env):
        if isinstance(form, Symbol):
            if form.lower() == 'nil': return None
            if form.lower() == 't': return True
            try: return float(form) if any(c in form.lower() for c in '.e') else int(form)
            except ValueError: return env[form]
        if not isinstance(form, list): return form
        if not form: return None
        op, *xs = form
        if op == 'quote': return xs[0]
        if op == 'progn': return self.body(xs, env)
        if op == 'cond':
            for test, *body in xs:
                value = self.eval(test, env)
                if truth(value):
                    return self.body(body, env) if body else value
            return None
        if op == 'setq':
            result = None
            for name, value in zip(xs[::2], xs[1::2]):
                result = self.eval(value, env)
                env[name] = result
            return result
        if op == 'if':
            if truth(self.eval(xs[0], env)): return self.eval(xs[1], env)
            return self.eval(xs[2], env) if len(xs) > 2 else None
        if op in ('and', 'or'):
            for arg in xs:
                value = truth(self.eval(arg, env))
                if op == 'and' and not value: return None
                if op == 'or' and value: return True
            return True if op == 'and' else None
        if op == 'foreach':
            result = None
            for value in self.eval(xs[1], env) or []:
                env[xs[0]] = value
                result = self.body(xs[2:], env)
            return result
        if op == 'while':
            count = 0
            while truth(self.eval(xs[0], env)):
                count += 1
                if count > 10000: raise ValueError('Loop limit')
                self.body(xs[1:], env)
            return None
        return self.invoke(op, [self.eval(x, env) for x in xs], env)
