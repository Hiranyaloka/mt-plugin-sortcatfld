package SortCatFld::Plugin;
use strict;

use ConfigAssistant::Util
    qw( plugin_static_web_path plugin_static_file_path);

my $plugin = MT->component('SortCatFld');

sub init_order_number {
    my $app = MT->instance;
    my $blog_class = $app->model('blog');
    my $cat_class = $app->model('category');
    my $fld_class = $app->model('folder');

    my @blogs = $blog_class->load;
    for my $blog (@blogs) {
        my $counter = 1;
        my @cats = $cat_class->load(
            { blog_id => $blog->id },
            { sort => 'label', direction => 'ascend' },
        );
        for my $cat (@cats) {
            $counter++ if ($cat->order_number);
        }
        for my $cat (@cats) {
            unless ($cat->order_number) {
                $cat->order_number($counter);
                $cat->save;
                $counter++;
            }
        }
        $counter = 1;
        my @flds = $fld_class->load(
            { blog_id => $blog->id },
            { sort => 'label', direction => 'ascend' },
        );
        for my $fld (@flds) {
            $counter++ if ($fld->order_number);
        }
        for my $fld (@flds) {
            unless ($fld->order_number) {
                $fld->order_number($counter);
                $fld->save;
                $counter++;
            }
        }
    }
}

sub sort_categories_entry {
    my ($cb, $app, $param, $tmpl) = @_;

    my $cats = $param->{category_tree};
    my $cat_count = scalar @$cats;
    my $type = ($app->mode eq 'sort_cat_setting')
        ? 'category' : 'folder';
    my $obj_class = $app->model($type);

    for (my $i = 0; $i < $cat_count; $i++) {
        my $cat_id = $cats->[$i]->{id};
        $cats->[$i]->{category_id} = $cat_id;
        if ($cat_id == -1) {
            $cats->[$i]->{category_order_number} = -1;
        }
        else {
            my $cat = $obj_class->load($cat_id);
            $cats->[$i]->{category_order_number} = $cat->order_number;
        }
    }
    &_sort_categories($app, $cats);
}

sub sort_categories_catlist {
    my ($cb, $app, $param, $tmpl) = @_;
    my ($msg, $mode);

    my $cats = $param->{category_loop};
    $param->{fjscaf_count} = scalar @$cats;

    if ($param->{fjscaf_count}) {
        if ($app->{query}->param('_type') eq 'folder') {
            $msg = $plugin->translate('Sort folders');
            $mode ="fld";
        }
        else {
            $msg = $plugin->translate('Sort categories');
            $mode = "cat";
        }
        my $css_url = plugin_static_web_path( $plugin ) . "css/styles.css";
        my $url = $param->{script_url} . "?__mode=sort_${mode}_setting&blog_id=" . $param->{blog_id};
        $param->{html_head} .= <<HERE;
    <link rel="stylesheet" href="$css_url" />
<script type="text/javascript">
//<[!CDATA[
TC.attachLoadEvent(function(){
    var doc = document;
    var newElm = doc.getElementById('create-new-link');
    var spaceElm = doc.createElement('span');
    spaceElm.innerHTML = '&nbsp;&nbsp;';
    newElm.appendChild(spaceElm);
    var sortElm = doc.createElement('a');
    sortElm.href = '$url';
    sortElm.className = 'icon-left icon-sort-categories';
    sortElm.innerHTML = '$msg';
    newElm.appendChild(sortElm);
});
//]]>
</script>
HERE

        &_sort_categories($app, $cats);
    }
}

sub _sort_categories {
    my $app = shift;
    my $cats = shift;

    my $cat_count = scalar @$cats;
    my $no_ordered_no = $cat_count + 1;

    my $type = ($app->mode eq 'sort_cat_setting')
        ? 'category' : 'folder';
    my $obj_class = $app->model($type);

    # create category tree
    my $cat_tree = {};
    my $cat_id;
    my $root_flag = 0;
    for (my $i = 0; $i < $cat_count; $i++) {
        $cat_id = $cats->[$i]->{category_id};
        my ($cat, @parent_cats);
        if ($cat_id > 0) {
            $cat = $obj_class->load($cat_id);
            if (defined($cat->order_number)) {
                $cats->[$i]->{category_order_number} = $cat->order_number;
            }
            else {
                $cats->[$i]->{category_order_number} = $no_ordered_no;
                $no_ordered_no++;
            }
            @parent_cats = $cat->parent_categories;
        }
        elsif ($cat_id == -1) {
            $cats->[$i]->{category_order_number} = -1;
            $root_flag = 1;
            @parent_cats = ();
        }
        if ($type eq 'folder' && $cat_id != -1 && $root_flag) {
            my $tmp_cat = $obj_class->new;
            $tmp_cat->id(-1);
            push @parent_cats, $tmp_cat;
        }
        @parent_cats = reverse @parent_cats;
        my $tmp_tree = $cat_tree;
        for my $parent_cat (@parent_cats) {
            unless(defined($tmp_tree->{$parent_cat->id})) {
                $tmp_tree->{$parent_cat->id} = {};
            }
            $tmp_tree = $tmp_tree->{$parent_cat->id};
       }
       $tmp_tree->{$cat_id} = { 
          cattree_index => $i,
          order_number => $cats->[$i]->{category_order_number},
          label => $cats->[$i]->{category_label},
       };
    }

    &_sort_cat_tree($cats, $cat_tree);
    @$cats = sort { $a->{category_order_number} <=>
                    $b->{category_order_number} } @$cats;
}

{
    my $order_no = 1;

    sub _sort_cat_tree {
        my $cats = shift;
        my $cat_tree = shift;

        my @cat_ids = keys %$cat_tree;
        @cat_ids = grep { $_ =~ /\d+/ } @cat_ids;
        return if (!@cat_ids);

        @cat_ids = sort { $cat_tree->{$a}->{order_number} <=> 
                          $cat_tree->{$b}->{order_number} } @cat_ids;

        for my $cat_id (@cat_ids) {
            $cat_tree->{$cat_id}->{order_number} = $order_no;
            my $cats_index = $cat_tree->{$cat_id}->{cattree_index};
            $cats->[$cats_index]->{category_order_number} = $order_no;
            $order_no++;
            &_sort_cat_tree($cats, $cat_tree->{$cat_id});
        }


    }
}

sub sort_categories_setting {
    my $app = shift;
    my %param;

    my $html = '';
    my $type = ($app->mode eq 'sort_cat_setting')
        ? 'category' : 'folder';
    my $obj_class = $app->model($type);

    &_build_category_tree($app, $obj_class, 0, 0, \$html);

    $param{sort_html} = $html;
    $param{script_url} = $app->{script_url};
    $param{blog_id} = $app->{query}->param('blog_id');
    $param{saved} = $app->{query}->param('saved');
    $param{next_mode} = ($app->mode eq 'sort_cat_setting')
        ? 'sort_cat_save' : 'sort_fld_save';
    $param{sort_obj} = ($app->mode eq 'sort_cat_setting')
        ? 'category' : 'folder';
    $param{folder_mode} = ($app->mode eq 'sort_cat_setting')
        ? 0 : 1;
    $param{sort_obj} = $plugin->translate($param{sort_obj});
    $param{not_found} = $plugin->translate(
                            ($app->mode eq 'sort_cat_setting')
                            ? 'Not found categories' : 'Not found folders');
    my $tmpl = $plugin->load_tmpl('sort_categories.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    return $app->build_page($tmpl, \%param);
}

sub _build_category_tree {
    my ($app, $obj_class, $parent, $level, $html) = @_;
    
    my $blog_id = $app->{query}->param('blog_id');

    my @cats = $obj_class->load({ blog_id => $blog_id, parent => $parent },
                                { sort => 'label', direction => 'ascend' });
    @cats = sort { $a->order_number <=> $b->order_number } @cats;
    my $cat_count = scalar(@cats);
    return if (!$cat_count);

    my $order_no = 1;
    my $no_order_no = $cat_count + 1;
    for (my $i = 0; $i < $cat_count; $i++) {
        if (defined($cats[$i]->order_number)) {
            $cats[$i]->order_number($order_no);
            $order_no++;
        }
        else {
            $cats[$i]->order_number($no_order_no);
            $no_order_no++;
        }

    }
    @cats = sort { $a->order_number <=> $b->order_number } @cats;

    my $sp1 = '';
    $sp1 = '  ' x ($level + 1);
    my $btn_path = plugin_static_web_path( $plugin ) . "images/";
    my $up_phrase = $plugin->translate('Up');
    my $down_phrase = $plugin->translate('Down');
    my $top_phrase = $plugin->translate('Top');
    my $bottom_phrase = $plugin->translate('Bottom');
    $$html .="${sp1}<ul";
    if ($level == 0) {
        $$html .= " id=\"category_root\"";
    }
    $$html .= ">\n";
    for (my $i = 0; $i < $cat_count; $i++) {
        my $cat = $cats[$i];
        my $class = ($i != $cat_count - 1) ? '' : ' class="tree_end"';
        my $up_id = 'cat' . $cat->id . 'u';
        my $down_id = 'cat' . $cat->id . 'd';
        my $top_id = 'cat' . $cat->id . 't';
        my $bottom_id = 'cat' . $cat->id . 'b';
        my $up_img = ($i) ? 'up.gif' : 'up_d.gif';
        my $down_img = ($i != $cat_count - 1) ? 'down.gif' : 'down_d.gif';
        my $top_img = ($i) ? 'top.gif' : 'top_d.gif';
        my $bottom_img = ($i != $cat_count - 1) ? 'bottom.gif' : 'bottom_d.gif';        my $up_onclick = ($i) ? ' onclick="return sort_category(this, \'up\');"' : '';
        my $down_onclick = ($i != $cat_count - 1) ? ' onclick="return sort_category(this, \'down\');"' : '';
        my $top_onclick = ($i) ? ' onclick="return sort_category(this, \'top\');"' : '';
        my $bottom_onclick = ($i != $cat_count - 1) ? ' onclick="return sort_category(this, \'bottom\');"' : '';
        my $icon_class_u = ($i) ? 'sort-icon' : 'sort-icon-d';
        my $icon_class_d = ($i != $cat_count - 1) ? 'sort-icon' : 'sort-icon-d';

        $$html .= "${sp1}<li${class} id=\"cat" . $cat->id . "\">";
        $$html .= "<img src=\"${btn_path}${top_img}\" id=\"${top_id}\" width=\"10\" height=\"10\"${top_onclick} alt=\"${top_phrase}\" title=\"${top_phrase}\" class=\"${icon_class_u}\" />";
        $$html .= "<img src=\"${btn_path}${up_img}\" id=\"${up_id}\" width=\"10\" height=\"10\"${up_onclick} alt=\"${up_phrase}\" title=\"${up_phrase}\" class=\"${icon_class_u}\" />";
        $$html .= "<img src=\"${btn_path}${down_img}\" id=\"${down_id}\" width=\"10\" height=\"10\"${down_onclick} alt=\"${down_phrase}\" title=\"${down_phrase}\" class=\"${icon_class_d}\" />";
        $$html .= "<img src=\"${btn_path}${bottom_img}\" id=\"${bottom_id}\" width=\"10\" height=\"10\"${bottom_onclick} alt=\"${bottom_phrase}\" title=\"${bottom_phrase}\" class=\"${icon_class_d}\" />";
        $$html .= $cat->label . "\n";
        &_build_category_tree($app, $obj_class, $cat->id, $level + 1, $html);
        $$html .= "$sp1</li>\n";
    }
    $$html .="$sp1</ul>\n";
}

sub sort_categories_save {
    my $app = shift;

    my $type = ($app->mode eq 'sort_cat_save')
        ? 'category' : 'folder';
    my $obj_class = $app->model($type);

    my @params = $app->{query}->param;
    for my $param (@params) {
        if ($param =~ /cat(\d+)/) {
            my $cat_id = $1;
            my $order_number = $app->{query}->param('cat' . $cat_id);
            my $cat = $obj_class->load($cat_id);
            $cat->order_number($order_number);
            $cat->save
                or return $app->error($plugin->translate('Save category error'));
        }
    }

    my $mode = ($app->mode eq 'sort_cat_save')
             ? 'sort_cat_setting' : 'sort_fld_setting';
    $app->redirect(
        $app->uri(mode => $mode,
                  args => { blog_id => $app->{query}->param('blog_id'),
                            saved => 1 }));
}

sub category_pre_save {
    my ($eh, $cat) = @_;

    unless (defined($cat->order_number)) {
        my @cats = MT::Category->load({ blog_id => $cat->blog_id });
        my $max = 0;
        map { $max = $_->order_number if ($max < $_->order_number) } @cats;
        $cat->order_number($max + 1);
    }
}

sub folder_pre_save {
    my ($eh, $fld) = @_;

    unless (defined($fld->order_number)) {
        my @flds = MT::Folder->load({ blog_id => $fld->blog_id });
        my $max = 0;
        map { $max = $_->order_number if ($max < $_->order_number) } @flds;
        $fld->order_number($max + 1);
    }
}

sub blog_config {
    my $blog = MT->instance->blog;
    my $blog_id = $blog->id;

    my $tmpl = <<HERE;
<p>
<a href="<mt:var name="mt_url">?__mode=sort_cat_setting&amp;blog_id=${blog_id}"><__trans phrase="Sort categories"></a><br />
<a href="<mt:var name="mt_url">?__mode=sort_fld_setting&amp;blog_id=${blog_id}"><__trans phrase="Sort folders"></a>
</p>
HERE
    $tmpl;
}

1;
