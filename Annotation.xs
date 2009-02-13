#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "hook_op_annotation.h"
#include "khash.h"

#if PTRSIZE == 8
#  define op_annotation_hash_64(key) (U32)(PTR2nat(key) >> 33 ^ PTR2nat(key) ^ PTR2nat(key) << 11)
   KHASH_INIT(anno, OP *, OPAnnotation *, 1, op_annotation_hash_64, kh_int64_hash_equal)
#else
#  define op_annotation_hash_32(key) (U32)(key)
   KHASH_INIT(anno, OP *, OPAnnotation *, 1, op_annotation_hash_32, kh_int_hash_equal)
#endif

#undef __ac_X31_hash_string

STATIC void op_annotation_free(pTHX_ OPAnnotation *annotation);

/* the data and/or destructor can be assigned later */
OPAnnotation * op_annotation_new(OPAnnotationGroup table, OP * op, void *data, OPAnnotationDtor dtor) {
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
    annotation->op_ppaddr = op->op_ppaddr;

    /*
     * kh_put returns an iterator, i.e. a key into the hash entries that can be used
     * to insert the value
     */ 

    k = kh_put(anno)(table, op, &ret);

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

    if (old) {
        op_annotation_free(aTHX_ old);
    }

    return annotation;
}

/* get the annotation for the current OP from the hash table */
OPAnnotation *op_annotation_get(OPAnnotationGroup table, OP *op) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    if (!op) {
        croak("B::Hooks::OP::Annotation: no OP supplied");
    }

    k = kh_get(anno)(table, op);

    if (k == kh_end(table)) { /* not found */
         croak("can't retrieve annotation: OP not found");
    }

    return kh_value(table, k);
}

void op_annotation_delete(pTHX_ OPAnnotationGroup table, OP *op) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    k = kh_get(anno)(table, op);

    if (k == kh_end(table)) { /* not found */
        croak("B::Hooks::OP::Annotation: can't delete annotation: OP not found");
    }

    op_annotation_free(aTHX_ kh_value(table, k));

    kh_del(anno)(table, k);
}

STATIC void op_annotation_free(pTHX_ OPAnnotation *annotation) {
    if (!annotation) {
        croak("B::Hooks::OP::Annotation: no annotation supplied");
    }

    if (annotation->data) {
        if (annotation->dtor) {
            CALL_FPTR(annotation->dtor)(aTHX_ annotation->data);
        } else {
            /* warn("B::Hooks::OP::Annotation: can't free annotation data: no dtor"); */
        }
    }

    Safefree(annotation);
}

OPAnnotationGroup op_annotation_group_new() {
    OPAnnotationGroup table;

    table = kh_init(anno)();

    if (!table) {
        croak("B::Hooks::OP::Annotation: can't allocate annotation group");
    }

    return table;
}

void op_annotation_group_free(pTHX_ OPAnnotationGroup table) {
    khiter_t k;

    if (!table) {
        croak("B::Hooks::OP::Annotation: no annotation group supplied");
    }

    for (k = kh_begin(table); k != kh_end(table); ++k) {
        if (kh_exist(table, k)) {
            op_annotation_free(aTHX_ kh_value(table, k));
        }
    }

    kh_clear(anno)(table);
    kh_destroy(anno)(table);
}

MODULE = B::Hooks::OP::Annotation                PACKAGE = B::Hooks::OP::Annotation

PROTOTYPES: DISABLE
