function enableSubmitButton() {
    var fc = $("#fc").val();
    if ($("#ign").val().length > 0 && $("#pkmn")[0].selectedIndex > 0 && /^\d{4}-\d{4}-\d{4}$/.test(fc)) {
        $("[type=submit]").removeAttr("disabled").removeAttr("title");
    } else {
        disableSubmitButton();
    }
}

function disableSubmitButton() {
    $("[type=submit]").attr("disabled", "disabled").attr("title", "Please fill all the fields and enter a valid Friend Code.");
}

$(document).ready(function() {
    enableSubmitButton();

    $("[type=submit]").click(function(e) {
        e.preventDefault();
        var message =  encodeURIComponent($("#ign").val()) + encodeURI('\n' + $("#fc").val() + '\n' + $('select').val() + '\n\nDO NOT EDIT THIS MESSAGE OR ITS SUBJECT -- JUST CLICK SEND!');
        window.location = 'http://www.reddit.com/message/compose/?to=CPTFlairBot3&subject=casualpokemontrades&message=' + message;
    });
    
    var propertyChangeUnbound = false;
    $("input[id]").on("propertychange", function(e) {
        if (e.originalEvent.propertyName == "value") {
            enableSubmitButton();
        }
    });

    $("input[id]").on("input", function() {
        if (!propertyChangeUnbound) {
            $("input").unbind("propertychange");
            propertyChangeUnbound = true;
        }
        enableSubmitButton();
    });
    
    $('select').change(function () {
        enableSubmitButton();
        $('.flair').removeAttr('class').addClass('flair flair-' + $(this).val());
    });
    
    $('#ign').keyup(function() {
        $('.ign').text($(this).val());
    });
    
    $('#fc').keyup(function() {
        var foo = $(this).val().split("-").join(""); // remove hyphens
        if (foo.length > 0) {
            foo = foo.match(new RegExp('.{1,4}', 'g')).join("-");
        }
        $(this).val(foo);
        $('.fc').text(foo);
    });
});