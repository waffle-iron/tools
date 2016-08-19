import java.util.Vector;
import java.util.Collections;
import java.util.Iterator;
import java.util.Enumeration;

public class EnumerationIterable<E> implements Iterable<E> {

    private Enumeration<E> en;

    public EnumerationIterable(Enumeration<E> en) {
        this.en = en;
    }

    public Iterator<E> iterator() {
        return new Iterator<E>() {
            public boolean hasNext() {
                return en.hasMoreElements();
            }
            public E next() {
                return en.nextElement();
            }
            public void remove() {
                throw new UnsupportedOperationException();
            }
        };
    }

    /**
     * コンストラクタを使うと new EnumrationIterable&lt;&gtl;(enumeration) のように
     * 若干書きづらいので、ファクトリーメソッド。
     * @param en Enumrationオブジェクト
     * @return 与えられた en を走査する Iterable オブジェクト。
     */
    public static <E> Iterable<E> of(Enumeration<E> en) {
        return new EnumerationIterable<E>(en);
    }


    /**
     * テスト用メイン。
     * @param args コマンド行引数(未使用)
     */
    public static void main(String[] args) {

        for (int e = 3; e < 8; e++) {
            int n = 1;
            for (int ni = 0; ni < e; ni++) {
                n *= 10;
            }

            System.out.println("n = " + n);

            Vector<Integer> v = new Vector<>(n);

            for (int i = 0; i < n; i++) {
                v.add(i);
            }

            long start;

            start = System.currentTimeMillis();
            for (Integer s: EnumerationIterable.of(v.elements())) {
                //System.out.println(s);
            }
            System.out.println("time(ms) = " + (System.currentTimeMillis() - start));

            start = System.currentTimeMillis();
            for (Integer s: Collections.list(v.elements())) {
                //System.out.println(s);
            }
            System.out.println("time(ms) = " + (System.currentTimeMillis() - start));
        }
    }
}

// vim:set ts=4 sw=4 et:
