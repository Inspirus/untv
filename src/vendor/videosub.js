// ==============================================================================
// VideoSub v0.9.9
// by Thomas Sturm, June 2010 - August 2012
// http://www.storiesinflight.com
// License MIT
//
// Ender is licensed under MIT - copyright 2012 Dustin Diaz & Jacob Thornton
// http://ender.no.de/
//
// Standards compliant video subtitles for HTML5 video tags. 
// Just add this library to your webpage, it will scan your page for HTML5
// video tags and if they contain a <track> subtitle, it will load and parse
// the subtitle file (only if it is in SRT standard) and display the subtitles over
// the playing video. The library can handle multiple video files in one page.
// Currently, VideoSub will kick in for all browsers even if they have native track
// support, since none are expected to support .SRT files at all.
// ==============================================================================

/*!
  * =======================================================
  * Ender: open module JavaScript framework
  * copyright Dustin Diaz & Jacob Thornton 2011 (@ded @fat)
  * https://ender.no.de
  * License MIT
  * Module's individual licenses still apply
  * Build: ender build jeesh reqwest
  * =======================================================
  */

/*
**
** hacked to shit by gordonwritescode - be warned
**
*/


var $VIDEOSUB = window.$;

function videosub_timecode_min(tc) {
  tcpair = tc.split(' --> ');
  return videosub_tcsecs(tcpair[0]);
}

function videosub_timecode_max(tc) {
  tcpair = tc.split(' --> ');
  return videosub_tcsecs(tcpair[1]);
}

function videosub_tcsecs(tc) {
  tc1 = tc.split(',');
  tc2 = tc1[0].split(':');
  secs = Math.floor(tc2[0]*60*60) + Math.floor(tc2[1]*60) + Math.floor(tc2[2]);
  return secs;
}

module.exports = function videosub_main(scope) {
  // detect media element track support in browser via the existence of the addtrack method
  var myVideo = window.document.createElement('video');
  var tracksupport = typeof myVideo.addTextTrack == "function" ? true : false;  // check for track element method, if it doesn't exist, the browser generally doesn't support track elements

  // first find all video tags
  return $VIDEOSUB('video', scope).each(function() {
    // find track tag (this should be extended to allow multiple tracks and trackgroups) and get URL of subtitle file
    var subtitlesrc = '';
    var el = this;
    if (el.childNodes.length) {
      console.log('has children')
      // first we check if the object is not empty, if the object has child nodes
      var children = el.childNodes;
      for (var i = 0; i < children.length; i++) {
        if (children[i].nodeName.toLowerCase() == 'track') {
          console.log('has track!');
          subtitlesrc = $VIDEOSUB(children[i]).attr('src');
        }
      
      };
    };
    if (subtitlesrc.indexOf('.srt') != -1) {                  // we have a track tag and it's a .srt file
      var videowidth = $VIDEOSUB(el).attr('width');             // set subtitle div as wide as video
      var fontsize = 12;
      if (videowidth > 400) {
        fontsize = fontsize + Math.ceil((videowidth - 400) / 100);
      }
      // var videocontainer = window.document.createElement("div");
      // $VIDEOSUB(videocontainer).css({
      //   'position': "relative"
      // });
      // // wrap the existing video into the new container
      // videocontainer.appendChild(el.cloneNode(true)); 
      // el.parentNode.replaceChild(videocontainer, el);
      // el = videocontainer.firstChild;
      var subcontainer = window.document.createElement("div");
      $VIDEOSUB(subcontainer).css({
        'position': 'absolute',
        'bottom': '34px',
        'width': (videowidth-50)+'px',
        'padding': '0 25px 0 25px',
        'textAlign': 'center',
        'backgroundColor': 'transparent',
        'color': '#ffffff',
        'fontFamily': 'Helvetica, Arial, sans-serif',
        'fontSize': fontsize+'px',
        'fontWeight': 'bold',
        'textShadow': '-1px 0px black, 0px 1px black, 1px 0px black, 0px -1px black'
      });
      $VIDEOSUB(subcontainer).addClass('videosubbar');
      $VIDEOSUB(subcontainer).appendTo(el.parentNode);

      // called on AJAX load onComplete (to work around element reference issues)
      el.update = function(req) { 
        el.subtitles = new Array();
        records = req.split('\n\r');
        for (var r=0;r<records.length;r++) {
          record = records[r];
          el.subtitles[r] = new Array();
          el.subtitles[r] = record.split('\r');
        }

        // console.log(el.subtitles)

        el.subcount = 0;

        // add event handler to be called when play button is pressed
        $VIDEOSUB(el).on('play', function(an_event){
          el.subcount = 0;
        });

        // add event handler to be called when video is done
        $VIDEOSUB(el).on('ended', function(an_event){
          el.subcount = 0;
        });

        // add event handler to be called when the video timecode has jumped
        $VIDEOSUB(el).on('seeked', function(an_event){
          el.subcount = 0;
          while (videosub_timecode_max(el.subtitles[el.subcount][1]) < this.currentTime.toFixed(1)) {
            el.subcount++;
            if (el.subcount > el.subtitles.length-1) {
              el.subcount = el.subtitles.length-1;
              break;
            }
          }
        });

        // add event handler to be called while video is playing
        $VIDEOSUB(el).on('timeupdate', function(an_event){
          var subtitle = '';
          // check if the next subtitle is in the current time range
          if (this.currentTime.toFixed(1) > videosub_timecode_min(el.subtitles[el.subcount][1])  &&  this.currentTime.toFixed(1) < videosub_timecode_max(el.subtitles[el.subcount][1])) {
            subtitle = el.subtitles[el.subcount][2];
            if (el.subtitles[el.subcount][3]) subtitle += el.subtitles[el.subcount][3]
          }
          // is there a next timecode?
          if (this.currentTime.toFixed(1) > videosub_timecode_max(el.subtitles[el.subcount][1])  && el.subcount < (el.subtitles.length-1)) {
            el.subcount++;
          }
          // update subtitle div  
          this.nextSibling.innerHTML = subtitle;
        });
      }

      // load the subtitle file
      // $VIDEOSUB.ajax({
      //   type: 'GET', 
      //   url: subtitlesrc,
      //   dataType: 'html',
      //   success: el.update
      // });

      subtitlesrc = subtitlesrc.replace('file://','');
      require('fs').readFile(subtitlesrc, function(err, data) {
        if (err) return;
        el.update(data.toString());
      });

    }
  });
};
