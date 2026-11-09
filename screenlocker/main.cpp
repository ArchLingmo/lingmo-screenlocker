/*
 * Copyright (C) 2021 CuteOS Team.
 *
 * Author:     Reion Wong <reionwong@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "application.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QProcess>
#include <QTranslator>
#include <QLocale>
#include <QFile>
#include <QDebug>

// This is the X11 locker. In the Wayland session the lock screen is KWin's
// (kscreenlocker with the Lingmo theme): a window here would only cover Xwayland.
// Whatever still starts lingmo-screenlocker there (old shortcuts, scripts) gets
// KWin's lock instead.
static bool isWaylandSession()
{
    return qEnvironmentVariable("XDG_SESSION_TYPE") == QLatin1String("wayland")
        || !qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY");
}

static int lockWithKWin(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"),
                                                          QStringLiteral("/ScreenSaver"),
                                                          QStringLiteral("org.freedesktop.ScreenSaver"),
                                                          QStringLiteral("Lock"));
    // KWin answers once the lock screen is up
    const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, 10000);
    if (reply.type() == QDBusMessage::ReplyMessage)
        return 0;

    qWarning() << "org.freedesktop.ScreenSaver.Lock failed:" << reply.errorMessage() << "- trying loginctl lock-session";
    return QProcess::execute(QStringLiteral("loginctl"), {QStringLiteral("lock-session")}) == 0 ? 0 : 1;
}

int main(int argc, char *argv[])
{
    if (isWaylandSession())
        return lockWithKWin(argc, argv);

    Application app(argc, argv);

    if (!QDBusConnection::sessionBus().registerService("com.lingmo.ScreenLocker")) {
        return -1;
    }

    if (!QDBusConnection::sessionBus().registerObject("/ScreenLocker", &app)) {
        return -1;
    }

    // Translations
    QLocale locale;
    QString qmFilePath = QString("%1/%2.qm").arg("/usr/share/lingmo-screenlocker/translations/").arg(locale.name());
    if (QFile::exists(qmFilePath)) {
        QTranslator *translator = new QTranslator(app.instance());
        if (translator->load(qmFilePath)) {
            app.installTranslator(translator);
        } else {
            translator->deleteLater();
        }
    }

    app.setQuitOnLastWindowClosed(false);
    app.initialViewSetup();
    return app.exec();
}
