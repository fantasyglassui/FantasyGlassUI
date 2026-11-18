local _, ns = ...

-- Where "Report a problem" asks people to send their report.
--
-- Put ONE address between the quotes below:
--   a web page     for example a form, an issues page or a Discord invite
--   or an email    for example  reports@example.com
--
-- It is shown at the top of the report window, in a box people can copy from.
-- Leave the quotes empty and no address is shown.
--
-- An add-on cannot send anything by itself: the game gives add-ons no access to the internet. The
-- person reporting copies the address into their browser (or mail program) and pastes the report.

ns.reportLink = "https://forms.gle/42WdBsDBFKhkaMub7"

-- How the report should reach that address.
--   true    people are asked to save the report as a text file (in Notepad or any text editor) and
--           upload the file. Use this when your form has a "File upload" question.
--   false   people are asked to paste the report straight into the page.
-- (An email address always gets "paste it into the email".)

ns.reportAsFile = true
