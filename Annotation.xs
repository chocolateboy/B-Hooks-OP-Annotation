#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "assert.h"

#include "hook_op_annotation.h"

typedef struct XOPAnnotation {
    OPAnnotation annotation;
    struct XOPAnnotation *prev;
    struct XOPAnnotation *next;
    OPAnnotationGroup list;
} XOPAnnotation;

struct OPAnnotationGroup {
    XOPAnnotation *head;
    OPAnnotationDtor dtor;
};

STATIC void xop_annotation_free(XOPAnnotation *xannotation, OPAnnotationDtor dtor);

STATIC void xop_annotation_free(XOPAnnotation *xannotation, OPAnnotationDtor dtor) {
    if (dtor) {
        CALL_FPTR(dtor)(aTHX_ xannotation->annotation.data);
    }

    Safefree(xannotation);
}

OPAnnotation * op_annotation_new(OPAnnotationGroup list, OPAnnotationPPAddr ppaddr, void *data) {
    XOPAnnotation *xannotation;

    assert(list);
    assert(ppaddr);

    Newx(xannotation, 1, XOPAnnotation);

    if (!xannotation) {
        croak("B::Hooks::OP::Annotation: Can't allocate op annotation");
    }

    xannotation->annotation.data = data;
    xannotation->annotation.ppaddr = ppaddr;

    if (list->head) {
        list->head->prev = xannotation;
    }

    xannotation->prev = NULL;
    xannotation->next = list->head;
    list->head = xannotation;

    xannotation->list = list;

    return (OPAnnotation *)xannotation;
}

void op_annotation_free(OPAnnotation *annotation) {
    XOPAnnotation *xannotation = (XOPAnnotation *)annotation;
    OPAnnotationGroup list = xannotation->list;

    if (xannotation->prev) {
        xannotation->prev->next = xannotation->next;
    }

    if (xannotation->next) {
        xannotation->next->prev = xannotation->prev;
    }

    if (xannotation == list->head) {
        list->head = NULL;
    }

    xop_annotation_free(xannotation, list->dtor);
}

OPAnnotationGroup op_annotation_group_new(OPAnnotationDtor dtor) {
    OPAnnotationGroup list;

    Newx(list, 1, struct OPAnnotationGroup);

    if (!list) {
        croak("B::Hooks::OP::Annotation: Can't allocate OP annotation group");
    }

    list->head = NULL;
    list->dtor = dtor;

    return list;
}

void op_annotation_group_free(OPAnnotationGroup list) {
    XOPAnnotation *xannotation;
    OPAnnotationDtor dtor = list->dtor;

    while ((xannotation = list->head)) {
        list->head = xannotation->next;
        xop_annotation_free(xannotation, dtor);
    }

    Safefree(list);
}

MODULE = B::Hooks::OP::Annotation                PACKAGE = B::Hooks::OP::Annotation

PROTOTYPES: DISABLE
