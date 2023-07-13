<?php
/**
 * Plugin Name: Block Emails
 * Description: Blocks sending of emails when using wp_mail function to send emails.
 * Author:      rtCamp
 * Author URI:  https://rtcamp.com
 * License:     GPL2
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Version:     1.0
 */

// Comment this code if you don't want to disable emails altogether.
if ( ! function_exists( 'wp_mail' ) ) {
    function wp_mail( $to, $subject, $message, $headers = '', $attachments = array() ) {
        return true;
    }
}
?>
