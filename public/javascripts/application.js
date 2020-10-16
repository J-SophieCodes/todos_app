// application.js


// $() is the jQuery object
$(function() {

  $("form.delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      // this.submit();

      var form = $(this); // 'this' refers to DOM element that fired the event
      
      var request = $.ajax({  // use $ to access jQuery object
        url: form.attr("action"),
        method: form.attr("method")
      });

      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
        form.parent("li").remove();
        } else if (jqXHR.status === 200) {
          document.location = data;
        }
      });
    }
  });

});