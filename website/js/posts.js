// SETTINGS

// Blog title
var blog_title = "Chico Blog"
//var message_title = "";
//var message_lead = "";

// Number of posts per page. 
var post_per_page = 2;

// Posts DATA
// [{ "title": "", 
//    "content": "", 
//    "author" : "",
//    "authorimage": "",
//    "timestamp": "", 
//    "tags" : [ "tag" : "", ... ],
//     
//  },..]
var post_data_url = "sample.json";



if (blog_title != "") {
    $("#blogtitle").text(blog_title);
}

// Fetch and process post_data
var jqxhr = $.getJSON(post_data_url);
jqxhr.complete(function() {
    var simpleblog = jQuery.parseJSON(jqxhr.responseText);
    var tags_transform = {
        tag: 'div',
        id: 'posttag',
        class: 'label label-info',
        html: '${tag}'
    };

    var id = 0;
    var transform =
        [{
        tag: 'div',
        id: function() {
            id = id + 1;
            return ("post_" + id);
        },
        class: 'row',
        children: [{
            tag: 'div',
            class: 'span2',
            children: [{
                tag: 'img',
                id: 'postimage',
                class: 'img-circle',
                src: '${authorimage}'
            }, ]
        }, {
            tag: 'div',
            class: 'span10',
            children: [{
                tag: 'h4',
                id: 'posttitle',
                html: '${title}'
            }, {
                tag: 'h6',
                id: 'postauthor',
                html: '${author}  ',
                children: [{
                    tag: 'small',
                    html: ' -  ${timestamp}'
                }]
            }]
        }, {
            tag: 'div',
            class: 'span12',
            children: [{
                tag: 'hr',
                class: 'soften'
            }]
        }, {
            tag: 'div',
            id: 'posttext',
            class: 'span12',
            children: [{
                tag: 'p',
                html: function() {
                    return (markdown.toHTML(this.content));
                }
            }, {
                tag: 'div',
                children: function() {
                    return (json2html.transform(this.tags, tags_transform));
                }
            }]
        }]
    }, {
        tag: 'br'
    }];

    $('#PostsContainer').json2html(simpleblog.reverse(), transform);
    $('#PostsContainer').paginate({
        itemsPerPage: post_per_page * 3
    });
});


$(document).ready(function() {

    $(document).keydown(function(e) {
        if (e.which == 37) { // Left arrow key code
            $('#PostsContainer-previous').click();
        } else if (e.which == 39) { // Right arrow key code
            $('#PostsContainer-next').click();
        } else if (e.which == 75) {
            // TODO: Implement j/k navigation from post to post.
        } else if (e.which == 74) {
            // TODO: Implement j/k navigation from post to post. 
        };
    });
});


$(window).scroll(function() {
    if ($(window).scrollTop() == $(document).height() - $(window).height()) {
        $('#PostsContainer-next').click();
    }
});