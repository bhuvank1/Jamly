Group 8 Jamly - Monita Mitra, Fareedah Ajisegiri, Rohan Pant, Bhuvan Kannaeganti
Contributions

Alpha

Monita Mitra: 25%
* Login/Signup Screen
* Creating a Post (backend logic)
* Designed the launch screen
Fareedah Ajisegiri: 25%
* Settings screen
* Account Settings screen
* Storing user information (name, email address, mobile number) in Firestore database
* Create a post screen
Rohan Pant: 25%
* Profile Screen
* Profile Screen post view
Bhuvan Kannaeganti: 25%
* Song Search
* Spotify Connect
* Spotify Profile Statistics
* Post Song Selection


Beta

Monita Mitra (Release 28%, Overall 25%):
* All of social feed 
   * Users can see all posts that their friends made
   * Users can add comments and likes on a post 
   * Double tap gesture recognizer to like/remove like from a post 
* All of post detail screen on profile screen (where users can view, like, and comment on their own posts)


Fareedah Ajisegiri (Release 24%, Overall 25%):
* Spotify connection popup in social feed screen
* Modify user’s information to include display name
* Entire settings page (dark mode - needs refining, notifications, delete account, about page)
* Track connection to create a post
* Adding song from post to Listen Later playlist
* Displaying Listen Later playlist


Bhuvan Kannaeganti (Release 27%, Overall 25%):
* Spotify feature caching for recommendations
* Groups features
   * Group creation/Adding friends to groups
   * Group playlist, adding songs from search or recommendations
   * Custom song recommendations system
   * Group display of playlist and temporary placeholder for group icon
   * Display groups a user is part of




Rohan Pant (Release 21%, Overall 25%):
* Displaying user profile and their details such as username and their friends
* Friends Feature
   * Users can add friends
   * Users can search for different users in the app through their display name
   * Users can view information about different users such as their name, the friends they have and see their posts
   * Users can view their posts and like and comment on them.




Application flow:
App should be executed in Iphone 16 Pro Max for UI to appear consistent
* Settings Screen: Navigate to settings from profile page
   * Enable reminder: users can enable reminder for app to notify them to visit app after certain hours of inactivity
   * Delete Account: user needs to re-enter password to delete account. Successful deletion redirects to log in screen
* Social Feed: The home screen
   * A user can view the likes and comments for a post by clicking on the respective buttons underneath the image where a popup modal will show up 
      * The likes screen stores the display names of the user 
      * The comments screen stores the display names of the user along with the respective text of the comment 
   * A user can like and remove a like from a friend’s post by double tapping on the image
   * A user can add a comment to the post by clicking on the comments button underneath the post image, typing text into the text field that shows up on the bottom of the popup modal, and then clicking the blue up arrow button
   * Listen Later:
      * User can click button (+ music note) on post to add/unadd song to listen later playlist
      * To view playlist, navigate to profile screen and click on music note on nav bar
* Profile Screen: Navigate to “My Profile” from the nav bar
   * Post Detail
      * A user can view all the posts that they made on the profile view controller screen
         * The thumbnail view of the post has the album image, the song rating, and the song name 
      * A user can view more details about the post by clicking on the respective cell for that post
      * The post detail screen is very similar to the posts on the social feed and the user can add likes and comments on their own post similar to the social feed 
* Search for users: Click the “Add Friends button” in “My Profile”
      * A user can search for different users in the app by typing their display name through the search bar
      * If the name is correct, it shows information about the user such as their name, their friends and the posts they have shared in the current screen.
      * Clicking on their posts allows you to view their likes and comments and like and comment it yourself. This screen is very similar to the post detail screen in “My Profile”
      * Clicking on the friends button goes to a different screen where you can view their friends and you can look at their details by clicking on them
      * The Add Friends button adds the user you have currently searched for as a friend which means their posts will now appear in your social feed. The button will not work if you are already friends with them
      * * Groups Screen: Navigate to “Groups” from the nav bar
   * Displays a tableView of the groups a user is a member of along with the groups description
   * Can click create group in order to create a new group with your preferred name and description
   * Groups Display: click on a group in the tableview
      * Displays the group name, description and the group playlist
      * Song Reccomendations: tap the lightbulb for song recommendations
         * Custom generated song reccomendations using features such as members favorite artist. Had to create my own custom system because the recommendations, similar-artists, song-features endpoints were disabled in Nov 2024
      * Song Search and Selection: tap the search icon
         * Allows you to search and tap on a song to add it to the group playlist




Deviations:
* Bhuvan
   * We originally intended to have a unique post feed for the group. I was delayed on my work since spotify API endpoints were removed from usage. This forced me to come up with a unique solution that finds songs from artists that members have as their top artists through its own logic. That was a pretty huge delay and so we currently only have a group playlist and I plan to add the feed to the group. I am not sure if I will include a group image yet due to firebase limitations. I also need to spend more time to improve the aesthetics of the groups screens


Important Info:
You must use one of the Spotify accounts provided to guarantee it works. If you need an email code, you can login to the protonmail for the first test account (spotifytestaccount123). You might be able to test personally using a premium Spotify account, but it is not guaranteed.


Spotify Account to use:
Main - 
spotifytestaccount123@proton.me
spotifytestaccount123
Backup -
Username - gamerman1337xx@gmail.com
Password - gamerman1337


Existing jamly accounts to view posts from friends:
Username - William.bulko@cs.utexas.edu
Password - test123456@


Username - stephanie@gmail.com
Password - Asdfasdf1!


Username - mona@gmail.com
Password - Asdfasdf1!


Username - courtney@gmail.com
Password - Asdfasdf1!


Username - disney@gmail.com
Password - Asdfasdf1!
