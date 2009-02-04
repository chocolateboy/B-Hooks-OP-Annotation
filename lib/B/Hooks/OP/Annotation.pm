package B::Hooks::OP::Annotation;

use 5.008000;

use strict;
use warnings;

use base qw(DynaLoader);

our $VERSION = '0.01';

sub dl_load_flags { 0x01 }

__PACKAGE__->bootstrap($VERSION);

1;

__END__

=head1 NAME

B::Hooks::OP::Annotation - Annotate and delegate hooked OPs

=head1 SYNOPSIS

    #include "hook_op_check.h"
    #include "hook_op_ppaddr.h"
    #include "hook_op_annotation.h"

    STATIC OPAnnotationGroup mymodule_annotations;

    STATIC void mymodule_mydata_free(pTHX_ void *mydata) {
        // ...
    }

    STATIC OP * mymodule_check_method_named(pTHX_ OP *op, void *unused) {
        OPAnnotation * annotation;
        MyData * mydata;

        mydata = mymodule_get_mydata(); /* metadata to be associated with this op */
        annotation = op_annotation_new(mymodule_annotations, op->op_ppaddr, mydata);
        hook_op_ppaddr(op, mymodule_method_named, annotation);
    }

    STATIC OP * mymodule_method_named(pTHX_ OP *op, void *user_data) {
        OPAnnotation * annotation;
        MyData * mydata;
        
        mydata = (MyData *)annotation->data;

        // ...

        if (ok) {
            return NORMAL;
        } else if (mymodule_stop_hooking(op)) { /* restore the previous op_ppaddr */
            op->op_ppaddr = annotation->ppaddr;
            op_annotation_free(annotation);
            return CALL_FPTR(op->op_ppaddr)(aTHX);
        } else {
            return CALL_FPTR(annotation->ppaddr)(aTHX); /* delegate to the previous op_ppaddr */
        }
    }

    MODULE = mymodule PACKAGE = mymodule

    BOOT:
        mymodule_annotations = op_annotation_group_new(mymodule_mydata_free);

    void
    END()
        CODE:
            op_annotation_group_free(mymodule_annotations);

    void
    setup()
        CODE:
            mymodule_hook_op_method_named_id = hook_op_check(OP_METHOD_NAMED, mymodule_check_method_named, NULL);

    void
    teardown()
        CODE:
            hook_op_check_remove(OP_METHOD_NAMED, mymodule_hook_op_method_named_id);

=head1 DESCRIPTION

This module provides a way for XS code that hijacks OP C<op_ppaddr> functions to delegate to (or restore) the previous
functions, whether assigned by perl or by another module. Typically this should be used in conjunction with
L<B::Hooks::OP::Check> and L<B::Hooks::OP::PPAddr>.

This module makes its types and functions available to XS code by utilising L<ExtUtils::Depends>.
Modules that wish to use these exports in their XS code should include something like the following
in their Makefile.PL:

    my $XS_DEPENDENCIES = eval {
        require ExtUtils::Depends;
        my %hash = ExtUtils::Depends->new(
            'Your::XS::Module' => 'B::Hooks::OP::Annotation', # &c. e.g. B::Hooks::OP::Check and/or B::Hooks::OP::PPAddr
        )->get_makefile_vars();
        \%hash
    } || {};

    WriteMakefile(
        NAME => 'Your::XS::Module',
        # ...
        PREREQ_PM => {
            # ...
            'B::Hooks::OP::Annotation' => 0,
            'ExtUtils::Depends'        => 0,
            # ...
        },
        # ...
        %$XS_DEPENDENCIES,
    );

Then C<use> C<B::Hooks::OP::Annotation> in your XS module's corresponding C<.pm> file.

=head2 TYPES

=head3 OPAnnotation

This struct contains two members:

=over

=item * C<data>, a C<void *> containing metadata that should be associated with the current OP

=item * C<ppaddr>, the  C<op_ppaddr> function (of type L<"OPAnnotationPPAddr">) that is being replaced 

=back

=head3 OPAnnotationGroup

Annotations are stored in groups. Multiple groups can be created, and each one manages
all the annotations associated with it. Groups are initialised with an optional destructor that is used
to clean up the values in the C<data> fields of its members. This destructor can be null if no cleanup is needed.
Annotations can be removed from the group and freed by calling L<"op_annotation_free">, and the group and all its
annotations can be destroyed by calling L<"op_annotation_group_free">.

=head3 OPAnnotationPPAddr

This typedef corresponds to the type of perl's C<op_ppaddr> functions i.e.: 

    typedef  OP *(*OPAnnotationPPAddr)(pTHX);

=head3 OPAnnotationDtor

This is the typedef for the destructor used to free or cleanup the user-supplied data:

    typedef void (*OPAnnotationDtor)(pTHX_ void *data);

=head2 FUNCTIONS

=head3 op_annotation_group_new

This function creates a new annotation group. This manages one or more annotations.
It takes a destructor (of type L<"OPAnnotationDtor">) as an argument. This is used
to free the C<data> pointer of the group's annotations when they're destroyed individually
by L<"op_annotation_free"> or collectively by L<"op_annotation_group_free">.

Typically, a group should be created for each different data type held in the C<data> slot
of the annotation objects. Thus there might be a group for OPs whose metadata is stored
in an C<AV *> and another group for OPs whose metadata is a C<HV *>.

    OPAnnotationGroup op_annotation_group_new(OPAnnotationDtor dtor);

=head3 op_annotation_new

This function creates a new annotation. It takes an L<"OPAnnotationGroup">, the previous op_ppaddr function
and a pointer to the metadata to be associated with the OP as arguments, and returns a pointer to the new annotation.

    OPAnnotation * op_annotation_new(OPAnnotationGroup group, OPAnnotationPPAddr ppaddr, void *data);

=head3 op_annotation_free

This removes the specified annotation from the group and frees its memory. If a destructor was supplied,
then it is called on the value in the C<data> slot.

    void op_annotation_free(OPAnnotation *annotation);

=head3 op_annotation_group_free

This function frees the memory allocated for the annotation group and its contents. If the destructor supplied
in the constructor call was non-null, then it is applied to each annotation's C<data> slot before the group is freed.

    void op_annotation_group_free(OPAnnotationGroup group);

=head2 EXPORT

None by default.

=head1 SEE ALSO

=over

=item * L<B::Hooks::OP::Check>

=item * L<B::Hooks::OP::PPAddr>

=back

=head1 AUTHOR

chocolateboy <chocolate@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 chocolateboy

This module is free software.

You may distribute this code under the same terms as Perl itself.

=cut
