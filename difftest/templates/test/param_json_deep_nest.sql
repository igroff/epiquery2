--parameters:
--@myJson json myJson

SELECT k FROM OpenJson(@myJson) WITH (k VARCHAR(32) '$.a.b.c.d.e.f.g.h.i.j.k');