import { concat } from '../../../util/encoding/buffer';

import { IS_FAMILYGRAM } from '../../../config';
import {
  generateRandomBytes,
  modExp,
  readBigIntFromBuffer,
  readBufferFromBigInt,
  sha1,
} from '../Helpers';

const TELEGRAM_SERVER_KEYS = [
  {
    fingerprint: BigInt('-3414540481677951611'),
    n: BigInt(
      '2937959817066933702298617714945612856538843112005886376816255642404751219133084745514657634448776440866'
      + '1701890505066208632169112269581063774293102577308490531282748465986139880977280302242772832972539403531'
      + '3160108704012876427630091361567343395380424193887227773571344877461690935390938502512438971889287359033'
      + '8945177273024525306296338410881284207988753897636046529094613963869149149606209957083647645485599631919'
      + '2747663615955633778034897140982517446405334423701359108810182097749467210509584293428076654573384828809'
      + '574217079944388301239431309115013843331317877374435868468779972014486325557807783825502498215169806323',
    ),
    e: 65537,
  },
  {
    fingerprint: BigInt('-5595554452916591101'),
    n: BigInt(
      '2534288944884041556497168959071347320689884775908477905258202659454602246385394058588521595116849196570'
      + '8222649399180603818074200620463776135424884632162512403163793083921641631564740959529419359595852941166'
      + '8489405859523376133330223960965841179548922160312292373029437018775884567383353986024616752250817918203'
      + '9315375750495263623495132323782003654358104782690612092797248736680529211579223142368426126233039432475'
      + '0785450942589751755390156647751460719351439969059949569615302809050721500330239005077889855323917509948'
      + '255722081644689442127297605422579707142646660768825302832201908302295573257427896031830742328565032949',
    ),
    e: 65537,
  },
];

// Testgram auth-server default RSA key (fingerprint -3591632762792723036).
const TESTGRAM_SERVER_KEYS = [
  {
    fingerprint: BigInt('-3591632762792723036'),
    n: BigInt(
      '0xbbededbec7160c0944bd5ca54de32be45a54d808e0ab3a101cf8f3a7af6bd1802dab46bcad7d0c51eefc17f15102a05a11b656e960731770233a5358a4eb6fbf01a197dac60a0ce2ba76ddf67c1c28904c0d64bd3bb333ffcc63cffb30201e15e7a5dc8ce86b8d41c9fc69e214aa2e9b4d317847189ebe719cb7acbe954cabdec66ba6fec6ddc745fb4763f672d5d1b9cecf2ea6e8803a51222a2961bb522d85f323146dcd17a4e21ab3bd614dd88b115b272ebb8ed1e4bf915aaec70cd9f0b989643678fd72ea35d1eb8b065374239dcbe8cd839e3eb1fd8c67279b35268f8db1fc7dbc223250f448c4736dac3ceb9ab8ad0817642208687e4dfb0a08ad7cf7',
    ),
    e: 65537,
  },
];

export const SERVER_KEYS = (IS_FAMILYGRAM ? TESTGRAM_SERVER_KEYS : TELEGRAM_SERVER_KEYS).reduce((acc, { fingerprint, ...keyInfo }) => {
  acc.set(fingerprint, keyInfo);
  return acc;
}, new Map<bigint, { n: bigint; e: number }>());

/**
 * Encrypts the given data known the fingerprint to be used
 * in the way Telegram requires us to do so (sha1(data) + data + padding)

 * @param fingerprint the fingerprint of the RSA key.
 * @param data the data to be encrypted.
 * @returns the cipher text, or undefined if no key matching this fingerprint is found.
 */
export async function encrypt(fingerprint: bigint, data: Uint8Array): Promise<Uint8Array | undefined> {
  const key = SERVER_KEYS.get(fingerprint);
  if (!key) {
    return undefined;
  }

  // len(sha1.digest) is always 20, so we're left with 255 - 20 - x padding
  const rand = generateRandomBytes(235 - data.length);

  const toEncrypt = concat(await sha1(data), data, rand);

  // rsa module rsa.encrypt adds 11 bits for padding which we don't want
  // rsa module uses rsa.transform.bytes2int(to_encrypt), easier way:
  const payload = readBigIntFromBuffer(toEncrypt, false);
  const encrypted = modExp(payload, BigInt(key.e), key.n);
  // rsa module uses transform.int2bytes(encrypted, keylength), easier:
  return readBufferFromBigInt(encrypted, 256, false);
}
