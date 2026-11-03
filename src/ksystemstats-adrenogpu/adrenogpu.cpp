// Adreno GPU sensors for KDE ksystemstats, backed by /sys/class/kgsl.
// Replaces the stock GPU plugin for this device (no AMD/NVIDIA/Xe here).

#include <QFile>
#include <QString>
#include <QVariant>

#include <KPluginFactory>

#include <systemstats/SensorContainer.h>
#include <systemstats/SensorObject.h>
#include <systemstats/SensorPlugin.h>
#include <systemstats/SensorProperty.h>

using namespace KSysGuard;

namespace
{
QString readSys(const char *path)
{
    QFile f(QString::fromLatin1(path));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromLatin1(f.readAll()).trimmed();
}
}

class AdrenoGpu : public SensorObject
{
    Q_OBJECT
public:
    explicit AdrenoGpu(SensorContainer *parent)
        : SensorObject(QStringLiteral("gpu0"), QStringLiteral("Adreno 650"), parent)
    {
        m_usage = new SensorProperty(QStringLiteral("usage"), QStringLiteral("Usage"), this);
        m_usage->setShortName(QStringLiteral("Usage"));
        m_usage->setUnit(UnitPercent);
        m_usage->setMin(0);
        m_usage->setMax(100);

        m_coreFrequency = new SensorProperty(QStringLiteral("coreFrequency"), QStringLiteral("Core Frequency"), this);
        m_coreFrequency->setShortName(QStringLiteral("Core"));
        m_coreFrequency->setUnit(UnitMegaHertz);

        m_temperature = new SensorProperty(QStringLiteral("temperature"), QStringLiteral("Temperature"), this);
        m_temperature->setShortName(QStringLiteral("Temp"));
        m_temperature->setUnit(UnitCelsius);

        m_name = new SensorProperty(QStringLiteral("name"), QStringLiteral("Name"), this);
        m_name->setValue(QStringLiteral("Adreno 650"));
    }

    void update()
    {
        QString busy = readSys("/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage");
        if (!busy.isEmpty()) {
            busy.remove(QLatin1Char('%'));
            m_usage->setValue(busy.trimmed().toDouble());
        }

        bool ok = false;
        const qulonglong hz = readSys("/sys/class/kgsl/kgsl-3d0/gpuclk").toULongLong(&ok);
        if (ok)
            m_coreFrequency->setValue(double(hz) / 1000000.0);

        const qlonglong milli = readSys("/sys/class/kgsl/kgsl-3d0/temp").toLongLong(&ok);
        if (ok && milli > 0)
            m_temperature->setValue(double(milli) / 1000.0);
    }

    qreal usage() const { return m_usage->value().toDouble(); }

private:
    SensorProperty *m_usage;
    SensorProperty *m_coreFrequency;
    SensorProperty *m_temperature;
    SensorProperty *m_name;
};

class AllGpus : public SensorObject
{
    Q_OBJECT
public:
    explicit AllGpus(SensorContainer *parent)
        : SensorObject(QStringLiteral("all"), QStringLiteral("All GPUs"), parent)
    {
        m_usage = new SensorProperty(QStringLiteral("usage"), QStringLiteral("All GPUs Usage"), this);
        m_usage->setShortName(QStringLiteral("Usage"));
        m_usage->setUnit(UnitPercent);
        m_usage->setMin(0);
        m_usage->setMax(100);
    }

    void setUsage(qreal value) { m_usage->setValue(value); }

private:
    SensorProperty *m_usage;
};

class AdrenoGpuPlugin : public SensorPlugin
{
    Q_OBJECT
public:
    AdrenoGpuPlugin(QObject *parent, const QVariantList &args)
        : SensorPlugin(parent, args)
    {
        m_container = new SensorContainer(QStringLiteral("gpu"), QStringLiteral("GPU"), this);
        m_gpu = new AdrenoGpu(m_container);
        m_all = new AllGpus(m_container);
        update();
    }

    QString providerName() const override { return QStringLiteral("gpu"); }

    void update() override
    {
        m_gpu->update();
        m_all->setUsage(m_gpu->usage());
    }

private:
    SensorContainer *m_container;
    AdrenoGpu *m_gpu;
    AllGpus *m_all;
};

// Expanded by hand: moc did not pick up Q_PLUGIN_METADATA when it was hidden
// inside the K_PLUGIN_FACTORY_WITH_JSON macro expansion.
class AdrenoGpuPluginFactory : public KPluginFactory
{
    Q_OBJECT
    Q_INTERFACES(KPluginFactory)
    Q_PLUGIN_METADATA(IID "org.kde.KPluginFactory" FILE "ksystemstats_plugin_adreno.json")
public:
    AdrenoGpuPluginFactory()
    {
        registerPlugin<AdrenoGpuPlugin>();
    }
};

#include "adrenogpu.moc"
