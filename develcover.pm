END {
    Devel::Cover::report() if Devel::Cover->can('report');
}

1;
