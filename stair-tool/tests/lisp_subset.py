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
            'eq': lambda a, b: a == b, 'equal': lambda a, b: a == b, 'fix': int, '1+': lambda n: n+1,
            '1-': lambda n: n-1,
            'type': lambda v: Symbol('STR') if isinstance(v, str) else Symbol('REAL'),
            'rem': lambda a,b:a%b, 'abs': abs, 'null': lambda v: not truth(v), 'length': lambda v: len(v or []),
            'min': min, 'max': max, 'nth': lambda i, v: v[i] if i < len(v) else None,
            'car': lambda v: v[0] if v else None,
            'cdr': lambda v: v[1] if isinstance(v, tuple) else (v[1:] if v else None),
            'cddr': lambda v: v[2:] if v else None, 'cdar': lambda v: v[0][1],
            'cadr': lambda v: v[1], 'caar': lambda v: v[0][0],
            'caadr': lambda v: v[1][0], 'cadadr': lambda v: v[1][1],
            'cadar': lambda v: v[0][1], 'last': lambda v: v[-1] if v else None,
            'cons': lambda head, tail: ([head]+(tail or [])) if tail is None or isinstance(tail, list) else (head, tail), 'list': lambda *xs: list(xs),
            'append': lambda *parts: [item for part in parts for item in (part or [])],
            'reverse': lambda v: list(reversed(v or [])), 'distance': dist,
            'itoa': lambda v: str(int(v)), 'strlen': len, 'strcat': lambda *s: ''.join(s),
            'substr': lambda s, start, length=None: s[start-1:] if length is None else s[start-1:start-1+length],
            'vl-string-search': lambda part, s: s.index(part) if part in s else None,
            'strcase': str.upper, 'vl-string-trim': lambda chars, s: s.strip(chars),
            'vl-string-subst': lambda new, old, s: s.replace(old, new, 1),
            'member': lambda v, seq: seq[seq.index(v):] if v in seq else None,
            'distof': lambda s, mode: self.number(s),
            'rtos': lambda v, mode, precision: f'{v:.{precision}f}',
            'inters': self.intersection,
        }
        self.host['mapcar'] = lambda fn, values: [self.call(fn, v) for v in values]
        self.host['apply'] = lambda fn, values: self.call(fn, *values)

    @staticmethod
    def number(s):
        try: return float(s)
        except ValueError: return None

    @staticmethod
    def intersection(a, b, c, d, bounded):
        r = [b[i]-a[i] for i in (0, 1)]
        s = [d[i]-c[i] for i in (0, 1)]
        q = [c[i]-a[i] for i in (0, 1)]
        cross = lambda u, v: u[0]*v[1]-u[1]*v[0]
        denominator = cross(r, s)
        if abs(denominator) < 1e-10: return None
        t, u = cross(q, s)/denominator, cross(q, r)/denominator
        if bounded and not (0 <= t <= 1 and 0 <= u <= 1): return None
        return [a[i]+t*r[i] for i in (0, 1)]

    def call(self, name, *args):
        return self.invoke(name, args, ChainMap({}))

    @classmethod
    def literal(cls, value):
        if isinstance(value, list): return [cls.literal(v) for v in value]
        if isinstance(value, Symbol):
            if value.lower() == 'nil': return None
            if value.lower() == 't': return True
            try: return float(value) if any(c in value.lower() for c in '.e') else int(value)
            except ValueError: return value
        return value

    def invoke(self, name, args, env):
        # AutoLISP shares value/function symbols. A dynamically bound number
        # must not silently fall back to a builtin, as a Lisp-2 evaluator would.
        if name in env:
            raise ValueError(f'bad function: {env[name]} (symbol {name})')
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
        if op == 'quote': return self.literal(xs[0])
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
