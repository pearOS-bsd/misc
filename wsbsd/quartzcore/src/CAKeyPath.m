/* Key paths of a layer with components: position.x, bounds.size.width, transform.rotation.z, transform.scale, ... The transform components are read from, and written back into, the decomposed matrix. */
#import "CALayerPrivate.h"

typedef struct { double tx, ty, tz, sx, sy, sz, rx, ry, rz; } CAXform;

/* Euler decomposition of a matrix without perspective: scale = lengths of the rows, rotation = what is left (applied in the order x, y, z), translation = last row */
static void CADecompose(CATransform3D m, CAXform *o)
{
	double r[3][3] = { { m.m11, m.m12, m.m13 }, { m.m21, m.m22, m.m23 }, { m.m31, m.m32, m.m33 } };
	double sx = sqrt(r[0][0] * r[0][0] + r[0][1] * r[0][1] + r[0][2] * r[0][2]);
	double sy = sqrt(r[1][0] * r[1][0] + r[1][1] * r[1][1] + r[1][2] * r[1][2]);
	double sz = sqrt(r[2][0] * r[2][0] + r[2][1] * r[2][1] + r[2][2] * r[2][2]);
	double det = r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1]) - r[0][1] * (r[1][0] * r[2][2] - r[1][2] * r[2][0]) + r[0][2] * (r[1][0] * r[2][1] - r[1][1] * r[2][0]);
	if (det < 0) sx = -sx;
	if (sx) for (int j = 0; j < 3; j++) r[0][j] /= sx;
	if (sy) for (int j = 0; j < 3; j++) r[1][j] /= sy;
	if (sz) for (int j = 0; j < 3; j++) r[2][j] /= sz;
	o->tx = m.m41; o->ty = m.m42; o->tz = m.m43; o->sx = sx; o->sy = sy; o->sz = sz;
	/* row-vector convention: the rows of the rotation are the images of the axes */
	double sinY = -r[0][2];
	if (sinY > 1) sinY = 1; if (sinY < -1) sinY = -1;
	o->ry = asin(sinY);
	if (fabs(sinY) < 0.999999) { o->rx = atan2(r[1][2], r[2][2]); o->rz = atan2(r[0][1], r[0][0]); }
	else { o->rx = atan2(-r[2][1], r[1][1]); o->rz = 0; }
}
static CATransform3D CACompose(const CAXform *x)
{
	CATransform3D t = CATransform3DMakeScale(x->sx, x->sy, x->sz);
	t = CATransform3DConcat(t, CATransform3DMakeRotation(x->rx, 1, 0, 0));
	t = CATransform3DConcat(t, CATransform3DMakeRotation(x->ry, 0, 1, 0));
	t = CATransform3DConcat(t, CATransform3DMakeRotation(x->rz, 0, 0, 1));
	t = CATransform3DConcat(t, CATransform3DMakeTranslation(x->tx, x->ty, x->tz));
	return t;
}

static NSArray *kTransformKeys;
static id TransformComponent(CATransform3D m, NSString *comp, BOOL set, id setValue, CATransform3D *out)
{
	CAXform x; CADecompose(m, &x);
	NSArray *c = [comp componentsSeparatedByString:@"."];
	NSString *a = c[0], *b = c.count > 1 ? c[1] : nil;
	double *slot = NULL; double *three[3] = { 0, 0, 0 }; double avg = 0; BOOL isScale = NO, isTrans2 = NO;
	if ([a isEqualToString:@"rotation"]) {
		if (!b || [b isEqualToString:@"z"]) slot = &x.rz; else if ([b isEqualToString:@"x"]) slot = &x.rx; else if ([b isEqualToString:@"y"]) slot = &x.ry;
	} else if ([a isEqualToString:@"scale"]) {
		if (!b) { isScale = YES; avg = (x.sx + x.sy + x.sz) / 3; three[0] = &x.sx; three[1] = &x.sy; three[2] = &x.sz; }
		else if ([b isEqualToString:@"x"]) slot = &x.sx; else if ([b isEqualToString:@"y"]) slot = &x.sy; else if ([b isEqualToString:@"z"]) slot = &x.sz;
	} else if ([a isEqualToString:@"translation"]) {
		if (!b) isTrans2 = YES; else if ([b isEqualToString:@"x"]) slot = &x.tx; else if ([b isEqualToString:@"y"]) slot = &x.ty; else if ([b isEqualToString:@"z"]) slot = &x.tz;
	}
	if (!set) {
		if (slot) return @(*slot);
		if (isScale) return @(avg);
		if (isTrans2) return [NSValue valueWithSize:NSMakeSize(x.tx, x.ty)];
		return nil;
	}
	if (slot) *slot = [setValue doubleValue];
	else if (isScale) { double v = [setValue doubleValue]; x.sx = x.sy = x.sz = v; }
	else if (isTrans2) { NSSize s = [setValue sizeValue]; x.tx = s.width; x.ty = s.height; }
	else return nil;
	*out = CACompose(&x);
	return @YES;
}

id CALayerValueForKeyPath(CALayer *l, NSString *kp)
{
	NSRange dot = [kp rangeOfString:@"."];
	if (dot.location == NSNotFound) return [l valueForKey:kp];
	NSString *key = [kp substringToIndex:dot.location], *rest = [kp substringFromIndex:dot.location + 1];
	id v = [l valueForKey:key];
	if ([key isEqualToString:@"transform"] || [key isEqualToString:@"sublayerTransform"] || [key isEqualToString:@"instanceTransform"])
		return TransformComponent([v CATransform3DValue], rest, NO, nil, NULL);
	if ([v isKindOfClass:[NSValue class]]) {
		const char *t = [v objCType]; double buf[8] = { 0 }; [v getValue:buf];
		if (!strstr(t, "Rect") && (strstr(t, "Point") || strstr(t, "Size"))) {
			if ([rest isEqualToString:@"x"] || [rest isEqualToString:@"width"]) return @(buf[0]);
			if ([rest isEqualToString:@"y"] || [rest isEqualToString:@"height"]) return @(buf[1]);
		} else if (strstr(t, "Rect")) {
			if ([rest isEqualToString:@"origin"]) return [NSValue valueWithPoint:NSMakePoint(buf[0], buf[1])];
			if ([rest isEqualToString:@"size"]) return [NSValue valueWithSize:NSMakeSize(buf[2], buf[3])];
			if ([rest isEqualToString:@"origin.x"]) return @(buf[0]); if ([rest isEqualToString:@"origin.y"]) return @(buf[1]);
			if ([rest isEqualToString:@"size.width"]) return @(buf[2]); if ([rest isEqualToString:@"size.height"]) return @(buf[3]);
		}
	}
	return [l valueForKey:kp];
}

void CALayerSetValueForKeyPath(CALayer *l, NSString *kp, id v)
{
	NSRange dot = [kp rangeOfString:@"."];
	if (dot.location == NSNotFound) { [l setValue:v forKey:kp]; return; }
	NSString *key = [kp substringToIndex:dot.location], *rest = [kp substringFromIndex:dot.location + 1];
	id cur = [l valueForKey:key];
	if ([key isEqualToString:@"transform"] || [key isEqualToString:@"sublayerTransform"] || [key isEqualToString:@"instanceTransform"]) {
		CATransform3D out;
		if (TransformComponent([cur CATransform3DValue], rest, YES, v, &out)) [l setValue:[NSValue valueWithCATransform3D:out] forKey:key];
		return;
	}
	if ([cur isKindOfClass:[NSValue class]]) {
		const char *t = [cur objCType]; double buf[8] = { 0 }; [cur getValue:buf]; double x = [v doubleValue];
		BOOL ok = NO;
		if (!strstr(t, "Rect") && (strstr(t, "Point") || strstr(t, "Size"))) {
			if ([rest isEqualToString:@"x"] || [rest isEqualToString:@"width"]) { buf[0] = x; ok = YES; }
			else if ([rest isEqualToString:@"y"] || [rest isEqualToString:@"height"]) { buf[1] = x; ok = YES; }
		} else if (strstr(t, "Rect")) {
			if ([rest isEqualToString:@"origin.x"]) { buf[0] = x; ok = YES; } else if ([rest isEqualToString:@"origin.y"]) { buf[1] = x; ok = YES; }
			else if ([rest isEqualToString:@"size.width"]) { buf[2] = x; ok = YES; } else if ([rest isEqualToString:@"size.height"]) { buf[3] = x; ok = YES; }
		}
		if (ok) { [l setValue:[NSValue valueWithBytes:buf objCType:t] forKey:key]; return; }
	}
	[l setValue:v forKey:kp];
}
