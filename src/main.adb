with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Integer_Text_IO;        use Ada.Integer_Text_IO;
with Ada.Numerics.Discrete_Random;

procedure Main is

   Number_Of_Threads : constant Integer := 6;
   Step              : constant Integer := 1;

   -- Опис типів
   subtype Thread_Id_Type is Integer range 0 .. Number_Of_Threads - 1; -- Не треба буде преведення типів
   type Stop_Flag_Array is array (Thread_Id_Type) of Boolean;

   -- Захищений об'єкт для керування зупинкою потоків
   protected type Break_Manager is
      procedure Allow_Stop(Thread_Id : Integer);
      function Should_Stop(Thread_Id : Integer) return Boolean;
   private
      Stop_Flags : Stop_Flag_Array := (others => False);
   end Break_Manager;

   protected body Break_Manager is
      procedure Allow_Stop(Thread_Id : Integer) is
      begin
         Stop_Flags(Thread_Id) := True;
      end Allow_Stop;

      function Should_Stop(Thread_Id : Integer) return Boolean is
      begin
         return Stop_Flags(Thread_Id);
      end Should_Stop;
   end Break_Manager;

   Break_Control : Break_Manager;


   task type Sum_Thread(Thread_Id : Integer);

   task body Sum_Thread is
      Sum   : Long_Integer := 0;
      Count : Integer := 1;
      Num   : Integer := Step;
   begin
     while not Break_Control.Should_Stop(Thread_Id) loop
         Sum := Sum + Long_Integer(Num);
         Num := Num + Step;
         Count := Count + 1;

         delay 0.01; --0.001
      end loop;


      Put_Line("Потік #" & Integer'Image(Thread_Id + 1) &
               " завершився: Сума = " & Long_Integer'Image(Sum) &
               ", Кількість елементів = " & Integer'Image(Count));
   end Sum_Thread;


   -- Генератор випадкових чисел
   subtype Delay_Range is Integer range 1000 .. 3000; --5000..10000
   package Rand is new Ada.Numerics.Discrete_Random(Delay_Range);
   Gen : Rand.Generator;

   -- Потік для рандомної зупинки інших потоків, анонімний тип + об'єкт, створюється та запускається автоматично
   task Stop_Thread;

   task body Stop_Thread is
      type ID_Array is array (Thread_Id_Type) of Integer;
      Threads : ID_Array;

      -- Fisher-Yates shuffle
      procedure Shuffle(A : in out ID_Array) is
      begin
         for I in reverse 1 .. A'Last loop
            declare
               J : constant Integer := Rand.Random(Gen) mod (I + 1);
               Tmp : Integer := A(I);
            begin
               A(I) := A(J);
               A(J) := Tmp;
            end;
         end loop;
      end Shuffle;

   begin
      -- Ініціалізація генератора
      Rand.Reset(Gen);

      -- Ініціалізація масиву ідентифікаторів
      for I in Threads'Range loop
         Threads(I) := I;
      end loop;

      -- Перемішати масив
      Shuffle(Threads);

      -- Послідовно зупиняємо потоки з випадковими затримками
      for I of Threads loop
         declare
            Delay_Millis : constant Integer := Rand.Random(Gen);
            Delay_Time   : Duration := Duration(Delay_Millis) / 1000.0;
         begin
            delay Delay_Time;
            Break_Control.Allow_Stop(I);
         end;
      end loop;
   end Stop_Thread;

   -- Масив задач, зберігаються посилання на динамічно створені об'єкти
   Threads : array (Thread_Id_Type) of access Sum_Thread;

begin
   -- Створення потоків
   for I in Threads'Range loop
      Threads(I) := new Sum_Thread(I);
   end loop;

end Main;
