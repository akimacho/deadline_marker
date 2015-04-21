$(function() {
		var $submit_btn = $('#submit_btn');
		var $event = $('#event');
		var $deadline = $('#deadline');
		$submit_btn.click(function() {
				var event_title = $event.val();
				var date = $deadline.val();
				var msg =
						"イベント名 : " + event_title + "\n日にち : " + date + "\nよろしいですか？";
				return confirm(msg);
		});
});
