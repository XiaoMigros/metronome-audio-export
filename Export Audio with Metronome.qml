//============================//
// Export Audio with Metronome
// v1.0
// changelog:
//============================//

import QtQuick 2.9
import MuseScore 3.0
import FileIO 3.0
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.2
import QtQuick.Controls 1.5
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.3

MuseScore {
	menuPath:		location + "." + pluginName
	description:	qsTr("Exports a combined audio file of metronome and score.")
	version:		"1.0"
	requiresScore:	true;
	id:				exportMetronome;
	
	//USER CHANGEABLE SETTINGS===========================================================================//
	property var location:		"File"	//Menu tab where the plugin appears
	property var pluginName:	qsTr("Export Audio with Metronome")	//Name under which the plugin appears
	//===================================================================================================//
	
	Component.onCompleted: {
		if (mscoreMajorVersion >= 4) {
			exportMetronome.title			= qsTr("Export Audio with Metronome");
			exportMetronome.categoryCode	= "export";
		}
	}//component
	
	property var fileType;
	property var capsFileType;
	property var channelVol;
	property var path;

	Settings {
		id:							settings
		category:					"Export Audio with Metronome Plugin"
		property var path;
		property alias mVolSlider:	mVolSlider.value
		property alias rVolSlider:	rVolSlider.value
		property alias fileTypeBox: fileTypeBox.currentIndex
		//property var fileType;
	}//settings
	
	MessageDialog {
		id: mu4Dialog
		title: qsTr("Unsupported MuseScore version")
		modality: Qt.ApplicationModal
		icon: StandardIcon.Warning
		standardButtons: StandardButton.Ok
		text: qsTr("This plugin does not support MuseScore 4.0")
		detailedText: qsTr("To export a score with metronome, enable it in the mixer.")
		onAccepted: {quit()}
	}//MessageDialog
	
	Dialog {
		id: settingsDialog
		title: qsTr("Configure Export")
		//text: "jkfjgjk"
		standardButtons: (StandardButton.Cancel | StandardButton.Ok)
		
		onAccepted: {
			createMetronome()
			settingsDialog.close()
		}
		
		onRejected: {
			settingsDialog.close()
		}
		
		GridLayout {
			id: settingsLayout
			anchors.margins: 10;
			columns: 3;
			
			Label {text: qsTr("Metronome Volume: ")}
			
			Slider {
				id:				mVolSlider
				value:			mVolSpinBox.value
				maximumValue:	127.0 // from / to in later QtQuick.Controls versions
				stepSize:		1.0
			}
			
			SpinBox {
				id:				mVolSpinBox
				implicitWidth:	80;
				implicitHeight:	30;
				value:			mVolSlider.value
				maximumValue:	127
			}
			
			Label {text: qsTr("Instruments Volume: ")}
			
			Slider {
				id:				rVolSlider
				value:			rVolSpinBox.value
				maximumValue:	100.0
				stepSize:		1.0
			}
			
			SpinBox {
				id:				rVolSpinBox
				implicitWidth:	80;
				implicitHeight:	30;
				value:			rVolSlider.value
				maximumValue:	100
				suffix:			qsTr("%")
			}
			
			Label {text: qsTr("File Type: ")}
			
			ComboBox {
				id: fileTypeBox;
				implicitWidth: 120; height: 30;
				currentIndex: 0;
				model: ListModel {
					ListElement {text: qsTr("MP3 Audio")}
					ListElement {text: qsTr("WAV Audio")}
					ListElement {text: qsTr("FLAC Audio")}
					ListElement {text: qsTr("OGG Audio")}
				}//model list
			}//combobox
			
		}//gridlayout
	}//settingsDialog
	
	function createMetronome() {
		curScore.startCmd(); //surround action with startCmd/endCmd to make it undoable
		
		//save real instruments' volume, then overwrite with desired export volume
		channelVol = new Array();
		var parts = curScore.parts;
		for (var i = 0; i < parts.length; ++i) {
			var part = parts[i];
			var instrs = part.instruments;
			for (var j = 0; j < instrs.length; ++j) {
				var instr = instrs[j];
				var channels = instr.channels;
				for (var k = 0; k < channels.length; ++k) {
					var channel = channels[k];
					channelVol.push(channel.volume)
					channel.volume = (channel.volume * rVolSlider.value / rVolSlider.maximumValue)
				}
			}
		}
		
		//metronome instrument setup
		curScore.appendPart("wood-blocks");
		var channels = curScore.parts[curScore.parts.length-1].instruments[curScore.parts[0].instruments.length-1].channels;
		//idk why it has to be the last part (maybe conflicting plugin part/actual part) but it works so...
		for (var i = 0; i < channels.length; ++i) {
			var channel = channels[i];
			channel.volume = mVolSlider.value;
		}
		
		//add metronome notes according to written (nominal) time signature
		var cursor = curScore.newCursor();
		cursor.rewind(Cursor.SCORE_START);
		cursor.staffIdx = curScore.nstaves - 1;
		
		while (cursor.measure) {
			var count = cursor.tick
			cursor.setDuration(1, cursor.measure.timesigNominal.denominator);
			cursor.addNote(cursor.measure.firstSegment.tick == cursor.tick ? 76 : 77, false); //accented first beat -> different note
			cursor.rewindToTick(count); //account for unwanted behavior in shortened measures
			cursor.next();
		}
		
		//get file type
		fileType = fileTypeBox.currentIndex
		if (fileType == 0) {fileType = "mp3"}
		if (fileType == 1) {fileType = "wav"}
		if (fileType == 2) {fileType = "flac"}
		if (fileType == 3) {fileType = "ogg"}
		capsFileType = fileType.toUpperCase();
		console.log("Detected File Type: " + capsFileType)
		
		//open file prompt window
		exportDialog.open();
	}//createMetronome()
	
	FileDialog {
        id: exportDialog
        title: qsTr("Select Target Folder")
		selectExisting:	false;
        selectFolder:	false;
		selectMultiple:	false;
        folder: (path == false || path == "") ? shortcuts.home : "file:///" + (path == false ? "" : path);
		nameFilters: [capsFileType + qsTr(" Audio File (*.") + fileType + qsTr(")")];
		
        onAccepted: {
			path = exportDialog.fileUrl.toString();
			path = path.replace(/^(file:\/{3})/,""); // remove prefixed "file:///"
			path = decodeURIComponent(path); // unescape html codes like '%23' for '#'
			finish(); //write the file with given parameters
        }//onAccepted

        onRejected: {
			path = false;
            console.log("no path selected")
			finish();
        }//onRejected
		
    } //FileDialog
	
	function finish() {
	
		if (path != false) {
			writeScore(curScore, path, fileType)
		}//if path
		
		//restore previous instrument volumes
		var parts = curScore.parts;
		for (var i = 0; i < parts.length; ++i) {
			var part = parts[i];
			var instrs = part.instruments;
			for (var j = 0; j < instrs.length; ++j) {
				var instr = instrs[j];
				var channels = instr.channels;
				for (var k = 0; k < channels.length; ++k) {
					var channel = channels[k];
					if (channelVol[0]) {
						channel.volume = channelVol.shift()
					}
				}
			}
		}
		
		curScore.endCmd();
		cmd("undo");
		cmd("save");
	}//finish()
	
	onRun: {
		if (mscoreMajorVersion < 4) {
			settingsDialog.open()
		} else {
			mu4Dialog.open()
		}
	}//onRun
	
}//MuseScore
