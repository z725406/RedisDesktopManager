import QtQuick 2.3
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import "./common"

Dialog {
    id: root    
    title: !settings || !settings.name ? qsTr("New Connection Settings") : qsTr("Edit Connection Settings - %1").arg(settings.name)

    property var settings
    property string quickStartGuideUrl: "http://docs.redisdesktop.com/en/latest/quick-start/"

    signal testConnection
    signal saveConnection(var settings)

    property var items: []
    property var sshItems: []
    property var sslItems: []
    property var sshEnabled
    property var sslEnabled

    function cleanStyle() {
        function clean(items_array) {
            for (var index=0; index < items_array.length; index++)
                if (items_array[index].enabled)
                    items_array[index].style = validStyleEnabled.style
                else
                    items_array[index].style = validStyleDisabled.style
        }

        clean(items)
        clean(sshItems)
        clean(sslItems)
        validationWarning.visible = false
    }

    function validate() {

        cleanStyle()

        function checkItems(items_array) {
            var errors = 0

            for (var index=0; index < items_array.length; index++) {
                var value = undefined

                if (items_array[index].text != undefined) {
                    value = items_array[index].text
                } else if (items_array[index].host != undefined) {
                    value = items_array[index].host
                } else if (items_array[index].path != undefined) {
                    value = items_array[index].path
                }

                if (value != undefined && value.length == 0) {
                    errors++
                    items_array[index].style = invalidStyle
                }
            }

            return errors
        }

        var errors_count = checkItems(items)

        if (sshEnabled)
            errors_count += checkItems(sshItems)

        if (sslEnabled)
            errors_count += checkItems(sslItems)

        return errors_count == 0
    }

    function hideLoader() {
        uiBlocker.visible = false
    }

    function showLoader() {
        uiBlocker.visible = true
    }

    function showMsg(msg) {
        dialog_notification.showMsg(msg)
    }

    function showError(err) {
        dialog_notification.showError(err)
    }

    onVisibleChanged: {
        if (visible)
            settingsTabs.currentIndex = 0
    }

    Component {
        id: invalidStyle

        TextFieldStyle {
            textColor: "red"
            background: Rectangle {
                radius: 2
                implicitWidth: 100
                implicitHeight: 24
                border.color: "red"
                border.width: 1
            }
        }
    }

    TextField { id: validStyleEnabled; visible: false}
    TextField { id: validStyleDisabled; visible: false; enabled: false}

    contentItem: Item {
        implicitWidth: 600
        implicitHeight: Qt.platform.os == "osx"? 600 : 675

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5

            TabView {
                id: settingsTabs
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Qt.platform.os == "osx"? 550 : 590

                Tab {
                    id: mainTab
                    title: qsTr("Connection Settings")

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Qt.platform.os == "osx"? 5 : 10

                        GroupBox {
                            title: qsTr("Main Settings")
                            Layout.fillWidth: true

                            GridLayout {
                                anchors.fill: parent
                                columns: 2

                                Label { text: qsTr("Name:") }

                                TextField {
                                    id: connectionName
                                    objectName: "rdm_connection_name_field"
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Connection Name")
                                    text: root.settings ? root.settings.name : ""                                    
                                    Component.onCompleted: root.items.push(connectionName)
                                    onTextChanged: root.settings.name = text
                                }

                                Label { text: qsTr("Address:") }

                                AddressInput {
                                    id: connectionAddress
                                    placeholderText: qsTr("redis-server host")
                                    host: root.settings ? root.settings.host : "127.0.0.1"
                                    port: root.settings ? root.settings.port : 6379
                                    Component.onCompleted: root.items.push(connectionAddress)
                                    onHostChanged: if (root.settings) root.settings.host = host
                                    onPortChanged: if (root.settings) root.settings.port = port
                                }

                                Label { text: qsTr("Auth:") }

                                PasswordInput {
                                    id: connectionAuth
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("(Optional) redis-server authentication password")
                                    text: root.settings ? root.settings.auth : ""
                                    onTextChanged: root.settings.auth = text
                                }
                            }
                        }

                        GroupBox {
                            title: qsTr("Security")

                            Layout.columnSpan: 2
                            Layout.fillWidth: true

                            ExclusiveGroup { id: connectionSecurityExGroup }

                            GridLayout {
                                anchors.fill: parent
                                columns: 2

                                RadioButton {
                                    text: qsTr("None")
                                    checked: root.settings ? !root.settings.sslEnabled && !root.settings.useSshTunnel() : true
                                    exclusiveGroup: connectionSecurityExGroup
                                    Layout.columnSpan: 2
                                }

                                RadioButton {
                                    id: sslRadioButton
                                    Layout.columnSpan: 2
                                    text: qsTr("SSL")
                                    exclusiveGroup: connectionSecurityExGroup
                                    checked: root.settings ? root.settings.sslEnabled : false
                                    Component.onCompleted: root.sslEnabled = Qt.binding(function() { return sslRadioButton.checked })
                                    onCheckedChanged: {
                                        root.settings.sslEnabled = checked
                                        root.cleanStyle()

                                        if (!checked) {
                                            sslLocalCertPath.path = ""
                                            sslPrivateKeyPath.path = ""
                                            sslCaCertPath.path = ""
                                        }
                                    }
                                }

                                Item { Layout.preferredWidth: 20 }

                                GridLayout {
                                    enabled: sslRadioButton.checked
                                    columns: 2
                                    Layout.fillWidth: true

                                    Label { text: qsTr("Public Key:") }

                                    FilePathInput {
                                        id: sslLocalCertPath
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("(Optional) Public Key in PEM format")
                                        nameFilters: [ "Public Key in PEM format (*.pem *.crt)" ]
                                        title: qsTr("Select public key in PEM format")
                                        path: root.settings ? root.settings.sslLocalCertPath : ""                                        
                                        onPathChanged: root.settings.sslLocalCertPath = path
                                    }

                                    Label { text: qsTr("Private Key:") }

                                    FilePathInput {
                                        id: sslPrivateKeyPath
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("(Optional) Private Key in PEM format")
                                        nameFilters: [ "Private Key in PEM format (*.pem *.key)" ]
                                        title: qsTr("Select private key in PEM format")
                                        path: root.settings ? root.settings.sslPrivateKeyPath : ""
                                        onPathChanged: root.settings.sslPrivateKeyPath = path
                                    }

                                    Label { text: qsTr("Authority:") }

                                    FilePathInput {
                                        id: sslCaCertPath
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("(Optional) Authority in PEM format")
                                        nameFilters: [ "Authority file in PEM format (*.pem *.crt)" ]
                                        title: qsTr("Select authority file in PEM format")
                                        path: root.settings ? root.settings.sslCaCertPath : ""
                                        onPathChanged: root.settings.sslCaCertPath = path
                                    }
                                }

                                RadioButton {
                                    id: sshRadioButton
                                    Layout.columnSpan: 2
                                    text: qsTr("SSH Tunnel")
                                    exclusiveGroup: connectionSecurityExGroup
                                    checked: root.settings ? root.settings.useSshTunnel() : false
                                    Component.onCompleted: root.sshEnabled = Qt.binding(function() { return sshRadioButton.checked })
                                    onCheckedChanged: {
                                        root.cleanStyle()

                                        if (!checked) {
                                            sshAddress.host = ""
                                            sshAddress.port = 22
                                            sshUser.text = ""
                                            sshPrivateKey.path = ""
                                            sshPassword.text = ""
                                        }
                                    }
                                }

                                Item { Layout.preferredWidth: 20 }

                                GridLayout {
                                    enabled: sshRadioButton.checked
                                    columns: 2
                                    Layout.fillWidth: true

                                    Label { text: qsTr("SSH Address:") }

                                    AddressInput {
                                        id: sshAddress
                                        placeholderText: qsTr("Remote Host with SSH server")
                                        port: root.settings ? root.settings.sshPort : 22
                                        host: root.settings ? root.settings.sshHost : ""
                                        Component.onCompleted: root.sshItems.push(sshAddress)
                                        onHostChanged: root.settings.sshHost = host
                                        onPortChanged: root.settings.sshPort = port
                                    }

                                    Label { text: qsTr("SSH User:") }

                                    TextField {
                                        id: sshUser
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("Valid SSH User Name")
                                        text: root.settings ? root.settings.sshUser : ""
                                        Component.onCompleted: root.sshItems.push(sshUser)
                                        onTextChanged: root.settings.sshUser = text
                                    }

                                    GroupBox {
                                        title: qsTr("Private Key")
                                        checkable: true
                                        checked: root.settings ? root.settings.sshPrivateKey : false

                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true

                                        FilePathInput {
                                            id: sshPrivateKey
                                            anchors.fill: parent
                                            placeholderText: qsTr("Path to Private Key in PEM format")
                                            nameFilters: [ "Private key in PEM format (*)" ]
                                            title: qsTr("Select private key in PEM format")
                                            path: root.settings ? root.settings.sshPrivateKey : ""
                                            onPathChanged: root.settings.sshPrivateKey = path
                                        }
                                    }

                                    GroupBox {
                                        title: qsTr("Password")
                                        checkable: true
                                        checked: root.settings ? root.settings.sshPassword : true

                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true

                                        PasswordInput {
                                            id: sshPassword
                                            anchors.fill: parent
                                            placeholderText: qsTr("SSH User Password")
                                            text: root.settings ? root.settings.sshPassword : ""
                                            onTextChanged: root.settings.sshPassword = text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Tab {
                    title: qsTr("Advanced Settings")

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 10

                        columns: 2

                        Label { text: qsTr("Keys glob-style pattern:") }

                        TextField
                        {
                            id: keysPattern
                            Layout.fillWidth: true
                            placeholderText: qsTr("Pattern which defines loaded keys from redis-server")
                            text: root.settings ? root.settings.keysPattern : "*"
                            Component.onCompleted: root.items.push(keysPattern)
                            onTextChanged: root.settings.keysPattern = text
                        }

                        Label { text: qsTr("Namespace Separator:") }

                        TextField
                        {
                            id: namespaceSeparator
                            Layout.fillWidth: true
                            objectName: "rdm_advanced_settings_namespace_separator_field"
                            placeholderText: qsTr("Separator used for namespace extraction from keys")
                            text: root.settings ? root.settings.namespaceSeparator : ":"
                            onTextChanged: root.settings.namespaceSeparator = text
                        }

                        Label { text: qsTr("Connection Timeout (sec):") }

                        SpinBox {
                            id: executeTimeout
                            Layout.fillWidth: true
                            minimumValue: 30
                            maximumValue: 100000
                            value: {                                
                                return root.settings ? (root.settings.executeTimeout / 1000.0) : 60
                            }
                            onValueChanged: root.settings.executeTimeout = value * 1000
                        }

                        Label { text: qsTr("Execution Timeout (sec):")}

                        SpinBox {
                            id: connectionTimeout
                            Layout.fillWidth: true
                            minimumValue: 30
                            maximumValue: 100000
                            value: root.settings ? (root.settings.connectionTimeout / 1000.0) : 60
                            onValueChanged: root.settings.connectionTimeout = value * 1000
                        }

                        Item {
                            Layout.columnSpan: 2
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item {
                id: validationWarning
                visible: false
                Layout.fillWidth: true

                implicitHeight: 25

                RowLayout {
                    anchors.centerIn: parent
                    Image {source: "qrc:/images/alert.svg"}
                    Text { text: qsTr("Invalid settings detected!")}
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Button {
                    objectName: "rdm_connection_settings_dialog_test_btn"
                    iconSource: "qrc:/images/offline.svg"
                    text: qsTr("Test Connection")
                    onClicked: {
                        showLoader()
                        root.testConnection(root.settings)
                    }
                }

                ImageButton {
                    Layout.preferredWidth: 25
                    Layout.preferredHeight: 25
                    imgSource: "qrc:/images/help.svg"
                    imgHeight: 30
                    imgWidth: 30
                    onClicked: Qt.openUrlExternally(root.quickStartGuideUrl)
                }

                Item { Layout.fillWidth: true }

                Button {
                    objectName: "rdm_connection_settings_dialog_ok_btn"
                    text: qsTr("OK")
                    onClicked: {
                        if (root.validate()) {                            
                            root.saveConnection(root.settings)
                            root.close()
                        } else {
                            validationWarning.visible = true
                        }
                    }
                }

                Button {
                    text: qsTr("Cancel")
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            id: uiBlocker
            visible: false
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.1)

            Item {
                anchors.fill: parent
                BusyIndicator { anchors.centerIn: parent; running: true }
            }

            MouseArea {
                anchors.fill: parent
            }
        }

        MessageDialog {
            id: dialog_notification
            objectName: "rdm_qml_connection_settings_error_dialog"
            visible: false
            modality: Qt.WindowModal
            icon: StandardIcon.Warning
            standardButtons: StandardButton.Ok

            function showError(msg) {
                icon = StandardIcon.Warning
                text = msg
                open()
            }

            function showMsg(msg) {
                icon = StandardIcon.Information
                text = msg
                open()
            }
        }
    }
}
