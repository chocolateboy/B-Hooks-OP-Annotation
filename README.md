# NAME

B::Hooks::OP::Annotation - annotate and delegate hooked OPs

# SYNOPSIS

```xs
#include "hook_op_check.h"
#include "hook_op_annotation.h"

STATIC OPAnnotationGroup MYMODULE_ANNOTATIONS;

STATIC void mymodule_mydata_free(pTHX_ void *mydata) {
    // ...
}

STATIC OP * mymodule_check_entersub(pTHX_ OP *op, void *unused) {
    MyData * mydata;

    mydata = mymodule_get_mydata(); /* metadata to be associated with this OP */
    op_annotate(MYMODULE_ANNOTATIONS, op, mydata, mymodule_mydata_free);
    op->op_ppaddr = mymodule_entersub;

    return op;
}

STATIC OP * mymodule_entersub(pTHX) {
    OPAnnotation * annotation;
    MyData * mydata;
    OP *op = PL_op;

    annotation = op_annotation_get(MYMODULE_ANNOTATIONS, op);
    mydata = (MyData *)annotation->data;

    // ...

    if (ok) {
        return NORMAL;
    } else if (mymodule_stop_hooking(op)) { /* restore the previous op_ppaddr */
        op->op_ppaddr = annotation->op_ppaddr;
        op_annotation_delete(MYMODULE_ANNOTATIONS, op);
        return op->op_ppaddr(aTHX);
    } else {
        return annotation->op_ppaddr(aTHX); /* delegate to the previous op_ppaddr */
    }
}

MODULE = mymodule PACKAGE = mymodule

BOOT:
    MYMODULE_ANNOTATIONS = op_annotation_group_new();

void
END()
    CODE:
        op_annotation_group_free(aTHX_ MYMODULE_ANNOTATIONS);

void
setup()
    CODE:
        mymodule_hook_op_entersub_id = hook_op_check(
            OP_ENTERSUB,
            mymodule_check_entersub,
            NULL
        );

void
teardown()
    CODE:
        hook_op_check_remove(OP_ENTERSUB, mymodule_hook_op_entersub_id);
```

# DESCRIPTION

This module provides a way for XS code that hijacks OP `op_ppaddr` functions to delegate to (or restore) the previous
functions, whether assigned by perl or by another module. Typically this should be used in conjunction with
[B::Hooks::OP::Check](https://metacpan.org/pod/B::Hooks::OP::Check).

`B::Hooks::OP::Annotation` makes its types and functions available to XS code by means of
[ExtUtils::Depends](https://metacpan.org/pod/ExtUtils::Depends). Modules that wish to use these exports in their XS code should
`use B::OP::Hooks::Annotation` in the Perl module that loads the XS, and include something like the
following in their Makefile.PL:

```perl
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

our %XS_PREREQUISITES = (
    'B::Hooks::OP::Annotation' => '0.44',
    'B::Hooks::OP::Check'      => '0.15',
);

our %XS_DEPENDENCIES = ExtUtils::Depends->new(
    'Your::XS::Module',
     keys(%XS_PREREQUISITES)
)->get_makefile_vars();

WriteMakefile(
    NAME          => 'Your::XS::Module',
    VERSION_FROM  => 'lib/Your/XS/Module.pm',
    PREREQ_PM => {
        'B::Hooks::EndOfScope' => '0.07',
        %XS_PREREQUISITES
    },
    ($ExtUtils::MakeMaker::VERSION >= 6.46 ?
        (META_MERGE => {
            configure_requires => {
                'ExtUtils::Depends' => '0.301',
                %XS_PREREQUISITES
            }})
        : ()
    ),
    %XS_DEPENDENCIES,
    # ...
);
```

## TYPES

### OPAnnotation

This struct contains the metadata associated with a particular OP i.e. the data itself, a destructor
for that data, and the `op_ppaddr` function that was defined when the annotation was created
by [`op_annotate`](#op_annotate) or [`op_annotation_new`](#op_annotation_new).

* `op_ppaddr`, the OP's previous `op_ppaddr` function (of type [`OPAnnotationPPAddr`](#opannotationppaddr))
* `data`, a `void *` to metadata that should be associated with the OP
* `dtor`, a function (of type [`OPAnnotationDtor`](#opannotationdtor)) used to free the metadata

The fields are all read/write and can be modified after the annotation has been created.

### OPAnnotationGroup

Annotations are stored in groups. Multiple groups can be created, and each one manages
all of the annotations associated with it.

Annotations can be removed from the group and freed by calling [`op_annotation_delete`](#op_annotation_delete),
and the group and all its members can be destroyed by calling [`op_annotation_group_free`](#op_annotation_group_free).

### OPAnnotationPPAddr

This typedef corresponds to the type of perl's `op_ppaddr` functions i.e.

```c
typedef  OP *(*OPAnnotationPPAddr)(pTHX);
```

### OPAnnotationDtor

This is the typedef for the destructor used to free the metadata associated with the OP.

```c
typedef void (*OPAnnotationDtor)(pTHX_ void *data);
```

## FUNCTIONS

### op_annotation_new

This function creates and returns a new OP annotation.

It takes an [`OPAnnotationGroup`](#opannotationgroup), an OP, a pointer to the metadata to be associated with the OP,
and a destructor for that data. The data can be NULL and the destructor can be NULL if no cleanup is required.

If an annotation has already been assigned for the OP, then it is replaced by the new annotation, and the
old annotation is freed, triggering the destruction of its data (if supplied) by its
destructor (if supplied).

```c
OPAnnotation * op_annotation_new(
    OPAnnotationGroup group,
    OP *op,
    void *data,
    OPAnnotationDtor dtor
);
```

### op_annotate

This function is a void version of [`op_annotation_new`](#op_annotation_new) for cases where the new annotation is
not needed.

```c
void op_annotate(
    OPAnnotationGroup group,
    OP *op,
    void *data,
    OPAnnotationDtor dtor
);
```

### op_annotation_get

This retrieves the annotation associated with the supplied OP. If an annotation has not been
assigned for the OP, it raises a fatal exception.

```c
OPAnnotation * op_annotation_get(OPAnnotationGroup group, OP *op);
```

### op_annotation_delete

This removes the specified annotation from the group and frees its memory. If a destructor was supplied,
it is called on the value in the `data` field (if supplied).

```c
void op_annotation_delete(pTHX_ OPAnnotationGroup group, OP *op);
```

### op_annotation_group_new

This function creates a new annotation group.

```c
OPAnnotationGroup op_annotation_group_new(void);
```

### op_annotation_group_free

This function destroys the annotations in an annotation group and frees the memory allocated for the group.

```c
void op_annotation_group_free(pTHX_ OPAnnotationGroup group);
```

# EXPORT

None by default.

# VERSION

0.44

# SEE ALSO

- [B::Hooks::OP::Check](https://metacpan.org/pod/B::Hooks::OP::Check)
- [B::Hooks::OP::PPAddr](https://metacpan.org/pod/B::Hooks::OP::PPAddr)

# AUTHOR

[chocolateboy](mailto:chocolate@cpan.org)

# COPYRIGHT AND LICENSE

Copyright (c) 2009-2011 chocolateboy

This module is free software. You may distribute it under the same terms as Perl itself.
