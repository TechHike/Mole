$(document).ready(function() {

	$('.confirm').click(function(event) {
		if (!confirm('Are you sure?')) {
			event.preventDefault();
		}
	});

	var url = window.location.href.toLowerCase();

	if (url == 'http://www.techhike.net/' || url.indexOf('index.html') > 0) {
		$('.more-posts').removeClass('hide');
	}

	$('.comments[data-enable="true"]').removeClass('hide');
	$('.comments.hide').remove()

});

function InitializeTweets(username) {
	var url = 'http://api.twitter.com/1/statuses/user_timeline/' + username + '.json?callback=?'
	$.getJSON(url, 
		function(data) {
			var bhtml = function(body, cls) {
				return "<div class=\"tweet " + cls + "\">" + tweep(urlize(body)) + "</div>";
			};
			var html = bhtml(data[0].text, "first") 
							+ bhtml(data[1].text, "") 
							+ bhtml(data[2].text, "") 
							+ bhtml(data[3].text, "") 
							+ bhtml(data[4].text, "") 
							+ bhtml(data[5].text, "") 
							+ bhtml(data[6].text, "") 
							+ bhtml(data[7].text, "") 
							+ bhtml(data[8].text, "") 
							+ bhtml(data[9].text, "");
			
			$("#tweet").html(html);
		}
	);
}

function urlize(input) {
	var exp = /(\b(https?|ftp|file):\/\/([-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|]))/ig;
	output = input.replace(exp,'<a href="$1" target="_blank">$3</a>');
	return output;
}

function tweep(input) {

	var exp = /(\@([\w|_]+))/ig;
	output = input.replace(exp,'<a href="http://www.twitter.com/$2" target="_blank">$1</a> ');
	//alert(input.replace(exp,'<a href="http://www.twitter.com/$2" target="_blank">$1</a> '));
	return output;
}

