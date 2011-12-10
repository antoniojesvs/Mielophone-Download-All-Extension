package
{
	import com.codezen.mse.playr.PlayrTrack;
	
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.FileReference;
	import flash.net.FileReferenceList;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.*;
	import flash.xml.XMLDocument;
	
	import mielophone.extensions.IMUIExtension;
	
	import mx.controls.Alert;
	import mx.controls.Button;
	import mx.core.FlexGlobals;
	import mx.managers.PopUpManager;
	import mx.utils.ObjectUtil;
	
	import org.hamcrest.mxml.object.Null;
	
	import spark.components.HGroup;
	import spark.components.VGroup;

	public class MUIExtension implements IMUIExtension
	{
		[Embed(source="/download.png")]
		private var icon:Class;
		private var tries:int;
		private var n_song:int;
		private var first_:Boolean;
		private var downloading:Boolean;
		private var all:Boolean;
		private var last:PlayrTrack;
		private var stream:URLStream;
		private var song_name:String;
		private var d_mode:int;
		private var b2:Button;
		private var alert:Alert;
		
		public function MUIExtension()
		{
			downloading = false;
			d_mode = 0;
			var g:VGroup = new VGroup();
			var gh:HGroup = new HGroup();
			//g.horizontalAlign = "center";
			var b:Button = new Button();
			b.x = b.y = 10;
			b.label = 'Download';
			b.setStyle("chromeColor", "#36679f");
			b.setStyle("color","#FFFFFF");
			b.setStyle("icon", icon);
			b.setStyle("iconPlacement","left");
			b.addEventListener(MouseEvent.CLICK, onDownloadClick);
			
			var b1:Button = new Button();
			b1.x = b1.y = 10;
			b1.label = 'Download All';
			b1.setStyle("chromeColor", "#42737D");
			b1.setStyle("color","#FFFFFF");
			b1.setStyle("icon", icon);
			b1.setStyle("iconPlacement","left")
			b1.addEventListener(MouseEvent.CLICK, onDownloadAllClick);
			
			b2 = new Button();
			b2.label = 'N    (Normal Mode)';
			b2.width = 25;
			b2.setStyle("buttonWidth", 2);
			b2.setStyle("chromeColor", "#36679f");
			b2.setStyle("color","#FFFFFF");
			b2.addEventListener(MouseEvent.CLICK, changeMode);
			
			gh.addElement(b);
			gh.addElement(b2);
			g.addElement(gh);
			g.addElement(b1);
			FlexGlobals.topLevelApplication.musicPlayer.playerButtons.addElement(g);
			
			//FlexGlobals.topLevelApplication.musicPlayer.playerButtons.addElement(b1);
		}
		private function changeMode(e:Event):void {
			if(downloading) return;
			d_mode = (d_mode+1)%4;
			//FlexGlobals.topLevelApplication.musicPlayer.playerButtons.removeElement(g);
			if(d_mode == 0) {
				b2.label = 'N    (Normal Mode)[~/Song]';
				b2.setStyle("chromeColor", "#36679f");
			}
			else if (d_mode == 1) {
				b2.label = 'H    (Hierarchy Mode)[~/Artist/Album/Song]';
				b2.setStyle("chromeColor", "#42737D");
			}
			else if (d_mode == 2) {
				b2.label = 'A    (Hierarchy Mode)[~/Artist/Song]';
				b2.setStyle("chromeColor", "#FF8000");
			}
			else if (d_mode == 3) {
				b2.label = 'M    (Manual Mode)[Asks Dir]';
				b2.setStyle("chromeColor", "#FF0000");
			}
			//FlexGlobals.topLevelApplication.musicPlayer.playerButtons.addElement(g);
		}
		
		private function onDownloadClick(e:Event):void{
			if(downloading) return;
			downloading = true;
			all = false;
			var track:PlayrTrack = FlexGlobals.topLevelApplication.musicPlayer.getCurrentTrack() as PlayrTrack;
			if (track == null) downloading = false;
			else download(track);
		}
		
		private function onDownloadAllClick(e:Event):void{
			if(downloading) return;
			downloading = true;
			all = true
			tries = 0;
			n_song = 0;
			var track:PlayrTrack = FlexGlobals.topLevelApplication.musicPlayer.getCurrentTrack() as PlayrTrack;
			first_ = track != null;
			last = null;
			try {
				FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song);
				if(d_mode != 3) alert = Alert.show("Downloading!", "State!");
				nextDownload();
			}catch (erObject:Error) {
				downloading = false;
			}
		}
		
		private function nextDownload():void{
			//Alert.show("hola "+n_song);
			
			 var track:PlayrTrack = FlexGlobals.topLevelApplication.musicPlayer.getCurrentTrack() as PlayrTrack;
			
			//Alert.show(htmlUnescape(track.titleName+" "+track.trackNumber), "Starting download.");
			//if(track != null) Alert.show(track.title  +" - "+  last  +" - "+  first);
			if(track != null && track.title != null && track != last) {
				download(track);
				
			} else if(all){
				++tries;
				if (tries%3==0)FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song); // Reload
				if (tries < 100) var intervalId:uint = setTimeout( nextDownload ,200);
				else {
					downloading = false;
					PopUpManager.removePopUp(alert);
					Alert.show("Download failed!", "Failed!");
				}
			}
			//FlexGlobals.topLevelApplication.musicPlayer.findNextSong();
			//Alert.show("Saldrá una alerta al terminar la descarga", "Starting download.");
//			if (tries < 5) var intervalId:uint = setTimeout( nextDownload ,3000);
//			else Alert.show("Download complete!", "Done!");
		}
		
		private function download(track:PlayrTrack):void {
			//Alert.show("dentro "+track.title  +" "+  last  +" "+  first);
			//Alert.show(String(track.title!= last), "Starting download.");
			var urlRequest:URLRequest;
			var ok:Boolean;
			ok = false;
			if(track.downloadRequest != null){
				urlRequest = track.downloadRequest;
				ok = true;
			}else if(track.file != null){
				urlRequest = new URLRequest(track.file);
				ok = true;
			}
			if (ok) {
				last = track;
				//var req:URLRequest = new URLRequest(url);
				//Alert.show("1");
				song_name = "";
				if(d_mode == 1 || d_mode == 2) song_name += track.artist ? htmlUnescape(track.artist)+"/" : "unknown/";
				if(d_mode == 1) song_name += track.album ? htmlUnescape(track.album)+"/" : "unknown/";
				if (track.artist) song_name += htmlUnescape(track.artist)+" - ";
				song_name += track.title ? htmlUnescape(track.title)+".mp3" : "unknown.mp3";
				
				//song_name = htmlUnescape(track.artist)+"/"+htmlUnescape(track.album)+"/"+htmlUnescape(track.artist)+" - "+htmlUnescape(track.title)+".mp3"
				if(d_mode != 3) {
					stream = new URLStream();
					stream.addEventListener(Event.COMPLETE, writeAirFile);
					stream.load(urlRequest);
				}
				else {
					var fr:FileReference = new FileReference();
					if (all) fr.addEventListener(Event.SELECT, onSelect);
					else fr.addEventListener(Event.COMPLETE, onFinish);
					fr.addEventListener(Event.CANCEL, onClose);
					fr.download(urlRequest, htmlUnescape(track.artist)+" - "+htmlUnescape(track.title)+".mp3");
				}
				//Alert.show(fr.name, "Starting download.");
			}
		}
		
		private function writeAirFile(evt:Event):void {
			var fileData:ByteArray = new ByteArray();
			stream.readBytes(fileData,0,stream.bytesAvailable);
			var file:File = File.documentsDirectory.resolvePath("Mielophone/"+song_name);
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.WRITE);
			fileStream.writeBytes(fileData,0,fileData.length);
			fileStream.close();
			//Alert.show(file.nativePath +" "+File.documentsDirectory);
			if(!all) {
				downloading = false;
				PopUpManager.removePopUp(alert);
				Alert.show("Download completed!", "Done!");
				return;
			}
			tries = 0;
			if(first_) first_ = false;
			else ++n_song;
			try {
				FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song);
				var intervalId:uint = setTimeout( nextDownload ,200);
				//Alert.show("song"+n_song);
			}catch (erObject:Error) {
				FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song-1);
				downloading = false;
				PopUpManager.removePopUp(alert);
				Alert.show("Download completed!", "Done!");
			}
			
		}
		
		private function onSelect(e:Event):void{
			tries = 0;
			++n_song;
			try {
				FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song);
				var intervalId:uint = setTimeout( nextDownload ,200);
			}catch (erObject:Error) {
				FlexGlobals.topLevelApplication.musicPlayer.playSongByNum(n_song-1);
				downloading = false;
				PopUpManager.removePopUp(alert);
				Alert.show("Download completed!", "Done!");
			}
		}
		
		private function onClose(e:Event):void{
			downloading = false;
			PopUpManager.removePopUp(alert);
			if(all && n_song > 0) Alert.show("Download completed!", "Done!");
		}
		
		private function onFinish(e:Event):void{
			downloading = false;
			Alert.show("Download completed!", "Done!");
		}
		
		// plugin details
		public function get PLUGIN_NAME():String{
			return "DL ALL Plugin";
		}
		
		public function get AUTHOR_NAME():String{
			return "AJ";
		}
		
		public static function htmlUnescape(str:String):String
		{
			return new XMLDocument(str).firstChild.nodeValue;
		}
		
//		private function nextDownload():void{
//			var track:PlayrTrack = FlexGlobals.topLevelApplication.musicPlayer.getCurrentTrack() as PlayrTrack;
//			//Alert.show(htmlUnescape(track.title), "Starting download.");
//			if(track.title != null && track.title != last) {
//				//Alert.show(String(track.title!= last), "Starting download.");
//				var urlRequest:URLRequest;
//				if(track.downloadRequest != null){
//					last = track.title;
//					urlRequest = track.downloadRequest;
//				}else if(track.file != null){
//					last = track.title;
//					urlRequest = new URLRequest(track.file);
//				}
//				
//				var fr:FileReference = new FileReference();
//				fr.addEventListener(Event.SELECT, onLoad);
//				fr.addEventListener(Event.CANCEL, onClose);
//				fr.download(urlRequest, htmlUnescape(track.artist)+" - "+htmlUnescape(track.title)+".mp3");
//				//Alert.show(fr.name, "Starting download.");
//				
//			} else {
//				++tries;
//				if (tries < 50) var intervalId:uint = setTimeout( nextDownload ,200);
//				else Alert.show("Download complete!", "Done!");
//			}
//			FlexGlobals.topLevelApplication.musicPlayer.findNextSong();
//			//Alert.show("Saldrá una alerta al terminar la descarga", "Starting download.");
//			//			if (tries < 5) var intervalId:uint = setTimeout( nextDownload ,3000);
//			//			else Alert.show("Download complete!", "Done!");
//		}
	}
}