#ifndef __HOOK_OP_ANNOTATION_H__
#define __HOOK_OP_ANNOTATION_H__

#include "perl.h"

START_EXTERN_C

typedef struct OPAnnotationGroupImpl *OPAnnotationGroup;
typedef  OP *(*OPAnnotationPPAddr)(pTHX);
typedef void (*OPAnnotationDtor)(pTHX_ void *data);

typedef struct {
    OPAnnotationPPAddr ppaddr;
    void *data;
    OPAnnotationDtor dtor;
} OPAnnotation;

OPAnnotationGroup op_annotation_group_new();
void op_annotation_group_free(pTHX_ OPAnnotationGroup group);
OPAnnotation * op_annotation_get(OPAnnotationGroup group, OP *op);
OPAnnotation * op_annotation_set(OPAnnotationGroup group, OP *op, void *data, OPAnnotationDtor dtor);
void op_annotation_delete(pTHX_ OPAnnotationGroup table, OP * annotation);
void op_annotation_free(pTHX_ OPAnnotation *annotation);

END_EXTERN_C

#endif
