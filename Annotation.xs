#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "hook_op_annotation.h"
#include "khash.h"

#if PTRSIZE == 8
KHASH_INIT(anno, OP *, OPAnnotation *, 1, kh_int64_hash_func, kh_int64_hash_equal);
#else
KHASH_INIT(anno, OP *, OPAnnotation *, 1, kh_int_hash_func, kh_int_hash_equal);
#endif

/* get the annotation for the current OP from the hash table */
OPAnnotation *op_annotation_get(OPAnnotationGroup table, OP *op) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    if (!op) {
        croak("B::Hooks::OP::Annotation: no OP supplied");
    }

    k = kh_get_anno(table, op);

    if (k == kh_end(table)) { /* not found */
         croak("can't retrieve annotation: OP not found");
    }

    return kh_value(table, k);
}

/* the data and/or destructor can be assigned lazily */
OPAnnotation * op_annotation_set(OPAnnotationGroup table, OP * op, void *data, OPAnnotationDtor dtor) {
    OPAnnotation *annotation;
    OPAnnotation *old = NULL;
    khiter_t k;
    int ret;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    if (!op) {
        croak("B::Hooks::OP::Annotation: no OP supplied");
    }

    Newx(annotation, 1, OPAnnotation);

    if (!annotation) {
        croak("B::Hooks::OP::Annotation: can't allocate annotation");
    }

    annotation->data = data;
    annotation->dtor = dtor;
    annotation->ppaddr = op->op_ppaddr;

    /*
     * kh_put returns an iterator, i.e. a key into the hash entries that can be used
     * to insert the value
     */ 

    k = kh_put_anno(table, op, &ret);

    /*
     * ret:
     *
     *     0: entry is occupied
     *     1: entry was empty
     *     2: entry was deleted
     */

    if (ret == 0) {
        old = kh_value(table, k);
    }

    kh_value(table, k) = annotation;

    return old;
}

void op_annotation_free(OPAnnotation *annotation) {
    if (!annotation) {
        croak("B::Hooks::OP::Annotation: no annotation supplied");
    }

    if (annotation->data) {
        if (annotation->dtor) {
            CALL_FPTR(annotation->dtor)(aTHX_ annotation->data);
        } else {
            warn("B::Hooks::OP::Annotation: can't free annotation: no dtor");
        }
    }

    Safefree(annotation);
}

void op_annotation_delete(OPAnnotationGroup table, OP *op) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    k = kh_get_anno(table, op);

    if (k == kh_end(table)) { /* not found */
        croak("B::Hooks::OP::Annotation: can't delete annotation: OP not found");
    }

    op_annotation_free(kh_value(table, k));

    kh_del_anno(table, k);
}

OPAnnotationGroup op_annotation_group_new() {
    OPAnnotationGroup table;

    table = kh_init_anno();

    if (!table) {
        croak("B::Hooks::OP::Annotation: can't allocate annotation group");
    }

    return table;
}

void op_annotation_group_free(OPAnnotationGroup table) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    for (k = kh_begin(table); k != kh_end(table); ++k) {
        if (kh_exist(table, k)) {
            op_annotation_free(kh_value(table, k));
        }
    }

    kh_destroy_anno(table);
}

MODULE = B::Hooks::OP::Annotation                PACKAGE = B::Hooks::OP::Annotation

PROTOTYPES: DISABLE
