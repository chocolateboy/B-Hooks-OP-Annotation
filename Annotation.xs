#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "hook_op_annotation.h"

typedef struct XOPAnnotation {
    OPAnnotation annotation;
    struct XOPAnnotation *prev;
    struct XOPAnnotation *next;
} XOPAnnotation;

struct OPAnnotationGroup {
    XOPAnnotation *head;
    XOPAnnotation *tail;
};

STATIC XOPAnnotation * xop_annotation_new();
STATIC void xop_annotation_free(XOPAnnotation *xannotation);

STATIC XOPAnnotation * xop_annotation_new() {
    XOPAnnotation *xannotation;

    Newxz(xannotation, 1, XOPAnnotation);

    if (!xannotation) {
        croak("B::Hooks::OP::Annotation: can't allocate op annotation");
    }

    return xannotation;
}

STATIC void xop_annotation_free(XOPAnnotation *xannotation) {
    OPAnnotation annotation;

    annotation = xannotation->annotation;

    if (annotation.dtor && annotation.data) {
        CALL_FPTR(annotation.dtor)(aTHX_ annotation.data);
    }

    Safefree(xannotation);
}

/* the data and/or destructor can be assigned later */
OPAnnotation * op_annotation_new(OPAnnotationGroup list, OPAnnotationPPAddr ppaddr, void *data, OPAnnotationDtor dtor) {
    XOPAnnotation *xannotation;

    if (!list) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    if (!ppaddr) {
        croak("B::Hooks::OP::Annotation: no ppaddr supplied");
    }

    xannotation = xop_annotation_new();
    xannotation->annotation.ppaddr = ppaddr;
    xannotation->annotation.data = data;
    xannotation->annotation.dtor = dtor;

    xannotation->next = list->head->next;
    xannotation->prev = list->head;
    list->head->next = xannotation;

    return (OPAnnotation *)xannotation;
}

void op_annotation_free(OPAnnotation *annotation) {
    XOPAnnotation *xannotation = (XOPAnnotation *)annotation;

    if (!annotation) {
        croak("B::Hooks::OP::Annotation: no annotation supplied");
    }

    xannotation->next->prev = xannotation->prev;
    xannotation->prev->next = xannotation->next;

    xop_annotation_free(xannotation);
}

OPAnnotationGroup op_annotation_group_new() {
    OPAnnotationGroup list;

    Newx(list, 1, struct OPAnnotationGroup);

    if (!list) {
        croak("B::Hooks::OP::Annotation: can't allocate annotation group");
    }

    list->head = xop_annotation_new();
    list->tail = xop_annotation_new();
    list->head->next = list->tail;
    list->tail->prev = list->head;

    return list;
}

void op_annotation_group_free(OPAnnotationGroup list) {
    XOPAnnotation *xannotation, *next;

    if (!list) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    xannotation = list->head;

    while (xannotation) {
        next = xannotation->next;
        xop_annotation_free(xannotation);
        xannotation = next;
    }

    Safefree(list);
}

MODULE = B::Hooks::OP::Annotation                PACKAGE = B::Hooks::OP::Annotation

PROTOTYPES: DISABLE
