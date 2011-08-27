package SortCatFld;
use strict;

sub Sort
{
    $MT::Template::Context::a->order_number <=>
    $MT::Template::Context::b->order_number;
}

1;
