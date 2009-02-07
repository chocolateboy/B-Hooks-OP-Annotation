package B::Hooks::OP::Annotation;

use 5.008000;

use strict;
use warnings;

use base qw(DynaLoader);

our $VERSION = '0.21';

sub dl_load_flags { 0x01 }

__PACKAGE__->bootstrap($VERSION);

1;

__END__

=head1 NAME

B::Hooks::OP::Annotation - Annotate and delegate hooked OPs

=head1 SYNOPSIS

    #include "hook_op_check.h"
    #include "hook_op_annotation.h"

    STATIC OPAnnotationGroup MYMODULE_ANNOTATIONS;

    STATIC void mymodule_mydata_free(pTHX_ void *mydata) {
        // ...
    }

    STATIC OP * mymodule_check_entersub(pTHX_ OP *op, void *unused) {
        OPAnnotation * clobbered;
        MyData * mydata;

        mydata = mymodule_get_mydata(); /* metadata to be associated with this op */

        clobbered = op_annotation_set(MYMODULE_ANNOTATIONS, op, mydata, mymodule_mydata_free);

        if (clobbered) {
            op_annotation_free(aTHX_ clobbered);
            croak("error: OP already annotated");
        }

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
            op->op_ppaddr = annotation->ppaddr;
            op_annotation_delete(MYMODULE_ANNOTATIONS, op);
            return CALL_FPTR(op->op_ppaddr)(aTHX);
        } else {
            return CALL_FPTR(annotation->ppaddr)(aTHX); /* delegate to the previous op_ppaddr */
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

=head1 DESCRIPTION

This module provides a way for XS code that hijacks OP C<op_ppaddr> functions to delegate to (or restore) the previous
functions, whether assigned by perl or by another module. Typically this should be used in conjunction with
L<B::Hooks::OP::Check|B::Hooks::OP::Check>.

C<B::Hooks::OP::Annotation> makes its types and functions available to XS code by means of
L<ExtUtils::Depends|ExtUtils::Depends>. Modules that wish to use these exports in their XS code should
C<use B::OP::Hooks::Annotation> in the Perl module that loads the XS, and include something like the
following in their Makefile.PL:

    my $XS_DEPENDENCIES = eval {
        require ExtUtils::Depends;
        my %hash = ExtUtils::Depends->new(
            'Your::XS::Module' => 'B::Hooks::OP::Annotation', B::Hooks::OP::Check
        )->get_makefile_vars();
        \%hash
    } || {};

    warn $@ if ($@);

    WriteMakefile(
        NAME => 'Your::XS::Module',
        # ...
        PREREQ_PM => {
            # ...
            'B::Hooks::OP::Check'      => 0,
            'B::Hooks::OP::Annotation' => 0,
            'ExtUtils::Depends'        => 0,
            # ...
        },
        # ...
        %$XS_DEPENDENCIES
    );

=head2 TYPES

=head3 OPAnnotation

This struct contains the metadata associated with a particular OP i.e. the data itself, a destructor
for that data, and the C<op_ppaddr> function that was defined when the annotation was created
by L<"op_annotation_set">.

=over

=item * C<ppaddr>, the C<op_ppaddr> function (of type L<"OPAnnotationPPAddr">) that is being replaced 

=item * C<data>, a C<void *> to metadata that should be associated with the current OP

=item * C<dtor>, a function (of type L<"OPAnnotationDtor">) used to free the metadata

=back

=head3 OPAnnotationGroup

Annotations are stored in groups. Multiple groups can be created, and each one manages
all of the annotations associated with it.

Annotations can be removed from the group and freed by calling L<"op_annotation_delete">,
and the group and all its members can be destroyed by calling L<"op_annotation_group_free">.

=head3 OPAnnotationPPAddr

This typedef corresponds to the type of perl's C<op_ppaddr> functions i.e.

    typedef  OP *(*OPAnnotationPPAddr)(pTHX);

=head3 OPAnnotationDtor

This is the typedef for the destructor used to free the metadata associated with the OP.

    typedef void (*OPAnnotationDtor)(pTHX_ void *data);

=head2 FUNCTIONS

=head3 op_annotation_group_new

This function creates a new annotation group.

    OPAnnotationGroup op_annotation_group_new(void);

=head3 op_annotation_group_free

This function destroys the annotations in an annotation group and frees the memory allocated for the group.

    void op_annotation_group_free(pTHX_ OPAnnotationGroup group);

=head3 op_annotation_set

This function annotates an OP with metadata that can later be recovered with L<"op_annotation_get">.
It takes an L<"OPAnnotationGroup">, the current OP, a pointer to the metadata to be associated with the OP,
and a destructor for that data. The data can be NULL and the destructor can be NULL if no cleanup is required.

    OPAnnotation * op_annotation_set(
        OPAnnotationGroup group,
        OP *op,
        void *data,
        OPAnnotationDtor dtor
    );

=head3 op_annotation_get

This retrieves the annotation associated with the supplied OP. If an annotation has not been
assigned for the OP, it raises a fatal exception.

    OPAnnotation * op_annotation_get(OPAnnotationGroup group, OP *op);

=head3 op_annotation_delete

This removes the specified annotation from the group and frees its memory. If a destructor was supplied,
it is called on the value in the C<data> field.

    void op_annotation_delete(pTHX_ OPAnnotationGroup group, OP *op);

=head3 op_annotation_free

This calls the destructor (if supplied) on the data (if supplied) and then frees the memory allocated for the
annotation. It should only be called on annotations that have been removed from their group i.e overwritten
annotations returned by L<"op_annotation_set">.

    void op_annotation_free(pTHX_ OPAnnotation *annotation);

=head1 EXPORT

None by default.

=head1 VERSION

0.21

=head1 SEE ALSO

=over

=item * L<B::Hooks::OP::Check|B::Hooks::OP::Check>

=item * L<B::Hooks::OP::PPAddr|B::Hooks::OP::PPAddr>

=back

=head1 AUTHOR

chocolateboy <chocolate@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 chocolateboy

This module is free software.

You may distribute this code under the same terms as Perl itself.

=cut
